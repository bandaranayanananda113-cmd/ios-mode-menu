#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#include <math.h>
#include <mach-o/dyld.h>
#include <mach/mach.h>
#include <mach/vm_map.h>
#include <libkern/OSCacheControl.h>
#include <string>

// Imgui library
#import "Esp/CaptainHook.h"
#import "Esp/ImGuiDrawView.h"
#import "IMGUI/imgui.h"
#import "IMGUI/imgui_internal.h" 
#import "IMGUI/imgui_impl_metal.h"
#import "IMGUI/Honkai.h"

// Patch library
#import "5Toubun/NakanoIchika.h"
#import "5Toubun/NakanoNino.h"
#import "5Toubun/NakanoMiku.h"
#import "5Toubun/NakanoYotsuba.h"
#import "5Toubun/NakanoItsuki.h"
#import "5Toubun/dobby.h"

#define kWidth  [UIScreen mainScreen].bounds.size.width
#define kHeight [UIScreen mainScreen].bounds.size.height
#define kScale [UIScreen mainScreen].scale

static bool MenDeal = true; 

// ==========================================
// 1. GAME OFFSETS PLACEHOLDERS
// ==========================================
#define OFFSET_NO_RECOIL       0x0000000 
#define OFFSET_FAST_SWAP       0x0000000 
#define OFFSET_FAST_RELOAD     0x0000000 
#define OFFSET_TELEPORT        0x0000000 

#define OFFSET_AIMBOT_LOCK     0x0000000 
#define OFFSET_SILENT_AIM      0x0000000 

#define OFFSET_UWORLD          0x0000000 
#define OFFSET_VIEW_MATRIX     0x0000000 
#define OFFSET_ENTITY_LIST     0x0000000 
#define OFFSET_LOCAL_PLAYER    0x0000000 

// ==========================================
// [NEW] 2. 3D & 2D MATH STRUCTURES (ESP සඳහා)
// ==========================================
struct Vector2 { float x, y; };
struct Vector3 { float x, y, z; };
struct Matrix { float m[4][4]; };

// ==========================================
// [NEW] 3. SAFE MEMORY READING (ESP සඳහා Memory කියවීම)
// ==========================================
template <typename T>
T ReadMemory(uintptr_t address) {
    T value = {};
    if (address == 0) return value;
    memcpy(&value, (void*)address, sizeof(T));
    return value;
}

// ==========================================
// [NEW] 4. WORLD TO SCREEN (3D ලෝකයේ සිට 2D Screen එකට)
// ==========================================
bool WorldToScreen(Vector3 worldPos, Vector2& screenPos, Matrix viewMatrix, float screenWidth, float screenHeight) {
    float w = viewMatrix.m[3][0] * worldPos.x + viewMatrix.m[3][1] * worldPos.y + viewMatrix.m[3][2] * worldPos.z + viewMatrix.m[3][3];
    
    // සතුරා කැමරාවට පිටිපස්සේ නම් අඳින්නේ නෑ
    if (w < 0.01f) return false; 
    
    float x = viewMatrix.m[0][0] * worldPos.x + viewMatrix.m[0][1] * worldPos.y + viewMatrix.m[0][2] * worldPos.z + viewMatrix.m[0][3];
    float y = viewMatrix.m[1][0] * worldPos.x + viewMatrix.m[1][1] * worldPos.y + viewMatrix.m[1][2] * worldPos.z + viewMatrix.m[1][3];
    
    screenPos.x = (screenWidth / 2) * (1.0f + x / w);
    screenPos.y = (screenHeight / 2) * (1.0f - y / w);
    
    return true;
}

// ==========================================
// 5. SAFE MEMORY PATCHING FUNCTIONS 
// ==========================================
uintptr_t get_GameModule_Base(const char* moduleName) {
    uint32_t count = _dyld_image_count();
    for (uint32_t i = 0; i < count; i++) {
        const char* name = _dyld_get_image_name(i);
        if (name && strstr(name, moduleName)) {
            return (uintptr_t)_dyld_get_image_header(i);
        }
    }
    return 0;
}

uintptr_t getLocalRealOffset(uintptr_t offset) {
    if (offset == 0) return 0; 
    static uintptr_t base = 0;
    if (base == 0) { base = get_GameModule_Base("GameAssembly.dylib"); }
    if (base == 0) return 0;
    return base + offset;
}

void safePatchMemory(uintptr_t address, const uint8_t* bytes, size_t size) {
    if (address == 0) return; 
    static uintptr_t base = get_GameModule_Base("GameAssembly.dylib");
    if (address == base) return; 
    vm_protect(mach_task_self(), (vm_address_t)address, size, FALSE, PROT_READ | PROT_WRITE);
    memcpy((void*)address, bytes, size);
    vm_protect(mach_task_self(), (vm_address_t)address, size, FALSE, PROT_READ | PROT_EXEC);
    sys_icache_invalidate((void*)address, size);
}

// ==========================================
// CLEAN SHADOW TEXT RENDERER 
// ==========================================
static void DrawCleanShadowText(ImDrawList* drawList, ImVec2 pos, const char* text, ImVec4 color, float fontSize, ImFont* font) {
    ImGui::PushFont(font);
    drawList->AddText(ImVec2(pos.x + 1.5f, pos.y + 1.5f), ImColor(0, 0, 0, 200), text);
    drawList->AddText(pos, ImColor(color.x, color.y, color.z, color.w), text);
    ImGui::PopFont();
}

NSString* DecodeBase64(NSString* encodedString) {
    NSData *decodedData = [[NSData alloc] initWithBase64EncodedString:encodedString options:0];
    return [[NSString alloc] initWithData:decodedData encoding:NSUTF8StringEncoding];
}

// ==========================================
// GLOBAL VARIABLES
// ==========================================
static ImFont* fontMain = nullptr;
static ImFont* fontTitle = nullptr;

static bool isKeyAuthLogged = false;
static char usernameInput[64] = ""; 
static char passwordInput[64] = ""; 
static std::string subExpiryDate = "N/A";
static std::string subDaysRemaining = "0";
static std::string loginErrorMessage = "";
static bool isAuthenticating = false;

// Cheat Config
static bool streamProof = true;
static bool isStreamProofUpdating = false; 

static bool masterAimbot = false;
static bool aimbotEnable = false;
static int selectedAimConfig = 0; 
static int selectedAimMethod = 0; 
static bool showFovCircle = false;
static float fovCircleColor[4] = {0.45f, 0.28f, 0.85f, 1.00f}; 
static bool ignoreKnocked = false;
static bool forceLock = false;
static int selectedHitbox = 0; 
static float fovRadius = 30.0f;
static float maxDistance = 100.0f;
static float hitChance = 61.0f;
static float lockSpeed = 5.0f; 

static bool enemyEsp = false;
static bool espLine = false;
static bool espBox = false;
static bool espHealth = false;
static bool espNickname = false;
static bool espDistance = false;
static bool espSkeleton = false;
static bool nearbyCount = false;
static float counterTextSize = 25.0f;

static bool noRecoil = false;
static bool fastSwap = false;
static bool fastReload = false;
static bool teleportEnemies = false;

static float menuAccentColor[4] = {0.45f, 0.28f, 0.85f, 1.00f}; 
static float menuTransparency = 0.95f;

static UITextField *hiddenTextField = nil;

// ==========================================
// 6. APPLY HACKS LOGIC (HEX PATCHING)
// ==========================================
void UpdateHacks() {
    if (!isKeyAuthLogged) return; 

    static bool lastMasterAim = false;
    static bool lastAimEnable = false;
    static int lastAimMethod = -1;

    if (masterAimbot && aimbotEnable) {
        if (!lastMasterAim || !lastAimEnable || lastAimMethod != selectedAimMethod) {
            if (selectedAimMethod == 0) {
                uintptr_t addr = getLocalRealOffset(OFFSET_SILENT_AIM);
                const uint8_t patch[] = { 0x20, 0x00, 0x80, 0xD2 }; 
                safePatchMemory(addr, patch, sizeof(patch));
            } else {
                uintptr_t addr = getLocalRealOffset(OFFSET_AIMBOT_LOCK);
                const uint8_t patch[] = { 0x00, 0x01, 0x80, 0xD2 };
                safePatchMemory(addr, patch, sizeof(patch));
            }
        }
    } else if (lastMasterAim && lastAimEnable && (!masterAimbot || !aimbotEnable)) {
        if (lastAimMethod == 0) {
            uintptr_t addr = getLocalRealOffset(OFFSET_SILENT_AIM);
            const uint8_t restore[] = { 0x00, 0x00, 0x00, 0x00 }; 
            safePatchMemory(addr, restore, sizeof(restore));
        } else {
            uintptr_t addr = getLocalRealOffset(OFFSET_AIMBOT_LOCK);
            const uint8_t restore[] = { 0x00, 0x00, 0x00, 0x00 }; 
            safePatchMemory(addr, restore, sizeof(restore));
        }
    }
    lastMasterAim = masterAimbot; lastAimEnable = aimbotEnable; lastAimMethod = selectedAimMethod;

    static bool lastNoRecoil = false;
    if (noRecoil != lastNoRecoil) {
        uintptr_t addr = getLocalRealOffset(OFFSET_NO_RECOIL);
        if (noRecoil) {
            const uint8_t patch[] = { 0x1F, 0x20, 0x03, 0xD5 }; 
            safePatchMemory(addr, patch, sizeof(patch));
        } else {
            const uint8_t restore[] = { 0xFF, 0x43, 0x00, 0xD1 }; 
            safePatchMemory(addr, restore, sizeof(restore));
        }
        lastNoRecoil = noRecoil;
    }
    // Fast Swap, Reload, Teleport logics same as before... (omitted to save space, assuming they are unchanged)
}

const char* GetClipboardTextFn(void* user_data) {
    UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
    return pasteboard.string ? [pasteboard.string UTF8String] : "";
}

void SetClipboardTextFn(void* user_data, const char* text) {
    UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
    pasteboard.string = [NSString stringWithUTF8String:text];
}

@interface ImGuiDrawView () <MTKViewDelegate, UITextFieldDelegate>
@property (nonatomic, strong) id <MTLDevice> device;
@property (nonatomic, strong) id <MTLCommandQueue> commandQueue;
@property (nonatomic, strong) MTKView *mtkViewObj;
@property (nonatomic, strong) UITextField *secureContainerField; 
@end

@implementation ImGuiDrawView

// ... [ඔයාගේ Login Code එක සහ MTK Setup එක වෙනස් වෙන්නේ නෑ] ...
// (කෙටි කරලා තියෙන්නේ, ඔයාගේ පරණ Code එකේ විදියටම තියාගන්න)

- (void)drawInMTKView:(MTKView*)view {
    ImGuiIO& io = ImGui::GetIO();
    io.DisplaySize.x = view.bounds.size.width;
    io.DisplaySize.y = view.bounds.size.height;

    // ... [Menu UI Code එක වෙනස් වෙන්නේ නෑ] ...

    id<MTLCommandBuffer> commandBuffer = [self.commandQueue commandBuffer];
    
    if (!isKeyAuthLogged) { [self.view setUserInteractionEnabled:YES]; } 
    else {
        [self.view setUserInteractionEnabled:(MenDeal ? YES : NO)];
        UpdateHacks();
    }

    MTLRenderPassDescriptor* renderPassDescriptor = view.currentRenderPassDescriptor;
    if (renderPassDescriptor != nil)
    {
        id <MTLRenderCommandEncoder> renderEncoder = [commandBuffer renderCommandEncoderWithDescriptor:renderPassDescriptor];
        [renderEncoder pushDebugGroup:@"ImGui Premium Cyber Login"];

        ImGui_ImplMetal_NewFrame(renderPassDescriptor);
        ImGui::NewFrame();
        
        // ... [අර කලින් තිබ්බ Menu UI එක මෙතන තියෙනවා] ...
        
        // ==========================================
        // [NEW] 7. ESP DRAWING LOOP (Background Draw List)
        // ==========================================
        ImDrawList* draw_list = ImGui::GetBackgroundDrawList();
        
        // FOV Circle එක Draw කරන කොටස
        if (isKeyAuthLogged && aimbotEnable && showFovCircle) {
            ImVec2 center = ImVec2(io.DisplaySize.x / 2.0f, io.DisplaySize.y / 2.0f);
            draw_list->AddCircle(center, fovRadius * 3.0f, ImColor(fovCircleColor[0], fovCircleColor[1], fovCircleColor[2], fovCircleColor[3]), 100, 1.2f);
        }

        // ESP අඳින කොටස (Lines, Boxes)
        if (isKeyAuthLogged && (enemyEsp || espLine || espBox)) {
            
            // ⚠️ මේක Placeholder එකක්. Game එකේ සැබෑ Offsets හොයාගත්තම මෙතන Comments අයින් කරලා පාවිච්චි කරන්න.
            
            /* 
            // 1. Game එකේ ViewMatrix එක Read කරනවා (3D -> 2D කරන්න)
            Matrix viewMatrix = ReadMemory<Matrix>(getLocalRealOffset(OFFSET_VIEW_MATRIX));
            
            // 2. Entity List එක (සතුරන්ගේ ලැයිස්තුව) Read කරනවා
            // (මෙතන For Loop එකක් ගහලා සතුරන් ඔක්කොම ගන්න ඕන)
            
            Vector3 enemyPos = {0, 0, 0}; // උදාහරණයක් විතරයි - මේක සතුරාගේ ඇත්ත පිහිටීම වෙන්න ඕන
            Vector2 screenPos;
            
            // 3. සතුරාගේ 3D පිහිටීම Screen එකේ තැනට (W2S) හරවනවා
            if (WorldToScreen(enemyPos, screenPos, viewMatrix, io.DisplaySize.x, io.DisplaySize.y)) {
                
                // Line එකක් අඳින්න ඕන නම්
                if (espLine) {
                    ImVec2 screenBottom = ImVec2(io.DisplaySize.x / 2, io.DisplaySize.y);
                    ImVec2 enemyScreenPos = ImVec2(screenPos.x, screenPos.y);
                    draw_list->AddLine(screenBottom, enemyScreenPos, ImColor(255, 0, 0, 255), 1.5f);
                }
                
                // Box එකක් අඳින්න ඕන නම්
                if (espBox) {
                    float boxWidth = 50.0f; // උදාහරණ
                    float boxHeight = 100.0f; // උදාහරණ
                    draw_list->AddRect(ImVec2(screenPos.x - boxWidth/2, screenPos.y - boxHeight), 
                                       ImVec2(screenPos.x + boxWidth/2, screenPos.y), 
                                       ImColor(0, 255, 0, 255), 0.0f, 0, 1.5f);
                }
            }
            */
        }

        ImGui::Render();
        ImDrawData* draw_data = ImGui::GetDrawData();
        ImGui_ImplMetal_RenderDrawData(draw_data, commandBuffer, renderEncoder);
      
        [renderEncoder popDebugGroup];
        [renderEncoder endEncoding];

        [commandBuffer presentDrawable:view.currentDrawable];
    }
    [commandBuffer commit];
}

- (void)mtkView:(MTKView*)view drawableSizeWillChange:(CGSize)size {}

@end
