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
#include <vector>

// ==========================================
// අවශ්‍ය වන Libraries (ImGui සහ Hooking)
// ==========================================
#import "Esp/CaptainHook.h"
#import "Esp/ImGuiDrawView.h"
#import "IMGUI/imgui.h"
#import "IMGUI/imgui_internal.h" 
#import "IMGUI/imgui_impl_metal.h"
#import "IMGUI/Honkai.h" // Font File

// Patch library (ඔයාගේ bypass / patch files)
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
// 1. GAME OFFSETS 
// (මේවා ඔයා හොයාගත්ත Offsets වලින් Update කරන්න)
// ==========================================
#define OFFSET_NO_RECOIL       0x0000000 
#define OFFSET_FAST_SWAP       0x0000000 
#define OFFSET_FAST_RELOAD     0x0000000 
#define OFFSET_TELEPORT        0x0000000 

#define OFFSET_AIMBOT_LOCK     0x0000000 
#define OFFSET_SILENT_AIM      0x0000000 

// ESP සඳහා අවශ්‍ය Offsets
#define OFFSET_UWORLD          0x0000000 
#define OFFSET_VIEW_MATRIX     0x0000000 
#define OFFSET_ENTITY_LIST     0x0000000 
#define OFFSET_LOCAL_PLAYER    0x0000000 
#define OFFSET_ESP_BONE        0x0000000 
#define OFFSET_CAMERA_FOV      0x0000000 

// ==========================================
// 2. 3D MATH & ESP STRUCTURES
// ==========================================
struct Vector2 {
    float x, y;
    Vector2() : x(0.f), y(0.f) {}
    Vector2(float X, float Y) : x(X), y(Y) {}
};

struct Vector3 {
    float x, y, z;
    Vector3() : x(0.f), y(0.f), z(0.f) {}
    Vector3(float X, float Y, float Z) : x(X), y(Y), z(Z) {}
};

struct FMatrix {
    float m[4][4];
};

// 3D ලෝකයේ තියෙන Enemy කෙනෙක්ගේ position එක Screen එකේ 2D තැනකට හරවන Function එක 
bool WorldToScreen(Vector3 worldPosition, Vector2& screenPosition, FMatrix viewMatrix, float width, float height) {
    float w = viewMatrix.m[0][3] * worldPosition.x + viewMatrix.m[1][3] * worldPosition.y + viewMatrix.m[2][3] * worldPosition.z + viewMatrix.m[3][3];
    if (w < 0.001f) return false;

    float x = viewMatrix.m[0][0] * worldPosition.x + viewMatrix.m[1][0] * worldPosition.y + viewMatrix.m[2][0] * worldPosition.z + viewMatrix.m[3][0];
    float y = viewMatrix.m[0][1] * worldPosition.x + viewMatrix.m[1][1] * worldPosition.y + viewMatrix.m[2][1] * worldPosition.z + viewMatrix.m[3][1];

    float invW = 1.0f / w;
    float screenX = (width / 2.0f) + (x * invW) * (width / 2.0f);
    float screenY = (height / 2.0f) - (y * invW) * (height / 2.0f);

    screenPosition = Vector2(screenX, screenY);
    return true;
}

// ==========================================
// 3. SAFE MEMORY PATCHING 
// (Game Memory එක ආරක්ෂිතව Edit කිරීම)
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
    if (base == 0) {
        base = get_GameModule_Base("GameAssembly.dylib"); // Unity Games වලට
    }
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
// 4. GLOBAL VARIABLES & CONFIG
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

// Hack Features Switches
static bool streamProof = true;
static bool isStreamProofUpdating = false; 

static bool masterAimbot = false;
static bool aimbotEnable = false;
static int selectedAimConfig = 0; 
static int selectedAimMethod = 0; 
static bool showFovCircle = false;
static float fovCircleColor[4] = {0.35f, 0.45f, 0.95f, 1.00f}; // Premium Blue Color
static bool ignoreKnocked = false;
static bool forceLock = false;
static int selectedHitbox = 0; 
static float fovRadius = 50.0f;
static float maxDistance = 150.0f;
static float hitChance = 80.0f;
static float lockSpeed = 5.0f; 

static bool enemyEsp = false;
static bool espLine = false;
static bool espBox = false;
static bool espHealth = false;
static bool espSkeleton = false;
static float counterTextSize = 25.0f;

static bool noRecoil = false;
static bool fastSwap = false;
static bool fastReload = false;
static bool teleportEnemies = false;

static float menuAccentColor[4] = {0.35f, 0.45f, 0.95f, 1.00f}; 
static float menuTransparency = 0.95f;
static UITextField *hiddenTextField = nil;

NSString* DecodeBase64(NSString* encodedString) {
    NSData *decodedData = [[NSData alloc] initWithBase64EncodedString:encodedString options:0];
    return [[NSString alloc] initWithData:decodedData encoding:NSUTF8StringEncoding];
}

// ==========================================
// 5. APPLY HACKS LOGIC (Hex Codes)
// Menu එකේ Button On/Off කරද්දී Hex Code වදින තැන
// ==========================================
void UpdateHacks() {
    if (!isKeyAuthLogged) return; 

    // --- AIMBOT ---
    static bool lastMasterAim = false;
    static bool lastAimEnable = false;
    static int lastAimMethod = -1;

    if (masterAimbot && aimbotEnable) {
        if (!lastMasterAim || !lastAimEnable || lastAimMethod != selectedAimMethod) {
            if (selectedAimMethod == 0) { // Silent Aim
                uintptr_t addr = getLocalRealOffset(OFFSET_SILENT_AIM);
                const uint8_t patch[] = { 0x20, 0x00, 0x80, 0xD2 }; 
                safePatchMemory(addr, patch, sizeof(patch));
            } else { // Lock Aim
                uintptr_t addr = getLocalRealOffset(OFFSET_AIMBOT_LOCK);
                const uint8_t patch[] = { 0x00, 0x01, 0x80, 0xD2 };
                safePatchMemory(addr, patch, sizeof(patch));
            }
        }
    } else if (lastMasterAim && lastAimEnable && (!masterAimbot || !aimbotEnable)) {
        if (lastAimMethod == 0) {
            uintptr_t addr = getLocalRealOffset(OFFSET_SILENT_AIM);
            const uint8_t restore[] = { 0x00, 0x00, 0x00, 0x00 }; // Original Hex
            safePatchMemory(addr, restore, sizeof(restore));
        } else {
            uintptr_t addr = getLocalRealOffset(OFFSET_AIMBOT_LOCK);
            const uint8_t restore[] = { 0x00, 0x00, 0x00, 0x00 }; // Original Hex
            safePatchMemory(addr, restore, sizeof(restore));
        }
    }
    lastMasterAim = masterAimbot; lastAimEnable = aimbotEnable; lastAimMethod = selectedAimMethod;

    // --- NO RECOIL ---
    static bool lastNoRecoil = false;
    if (noRecoil != lastNoRecoil) {
        uintptr_t addr = getLocalRealOffset(OFFSET_NO_RECOIL);
        if (noRecoil) {
            const uint8_t patch[] = { 0x1F, 0x20, 0x03, 0xD5 }; // NOP 
            safePatchMemory(addr, patch, sizeof(patch));
        } else {
            const uint8_t restore[] = { 0xFF, 0x43, 0x00, 0xD1 }; 
            safePatchMemory(addr, restore, sizeof(restore));
        }
        lastNoRecoil = noRecoil;
    }

    // --- FAST SWAP ---
    static bool lastFastSwap = false;
    if (fastSwap != lastFastSwap) {
        uintptr_t addr = getLocalRealOffset(OFFSET_FAST_SWAP);
        if (fastSwap) {
            const uint8_t patch[] = { 0x00, 0x00, 0x80, 0xD2 }; 
            safePatchMemory(addr, patch, sizeof(patch));
        } else {
            const uint8_t restore[] = { 0xF4, 0x4F, 0x01, 0xA9 }; 
            safePatchMemory(addr, restore, sizeof(restore));
        }
        lastFastSwap = fastSwap;
    }
}

// ==========================================
// 6. RENDER ESP (Screen එකේ අඳින කොටස)
// ==========================================
void RenderESP(ImDrawList* drawList, ImVec2 displaySize) {
    if (!enemyEsp) return;

    // මෙහිදී ඔයාගේ Game Entity Loop එක ලියන්න ඕනේ. (Memory Reading)
    // උදාහරණයක් විදිහට Box සහ Line අඳින Code එක පහතින් තියෙනවා:
    /*
    Vector2 screenHead, screenFeet;
    if (WorldToScreen(enemyHeadPos, screenHead, viewMatrix, displaySize.x, displaySize.y) &&
        WorldToScreen(enemyFeetPos, screenFeet, viewMatrix, displaySize.x, displaySize.y)) {
        
        float height = fabsf(screenFeet.y - screenHead.y);
        float width = height / 2.0f;
        
        if (espBox) {
            drawList->AddRect(ImVec2(screenHead.x - width/2, screenHead.y), ImVec2(screenHead.x + width/2, screenFeet.y), IM_COL32(255, 0, 0, 255), 0, 0, 1.5f);
        }
        if (espLine) {
            drawList->AddLine(ImVec2(displaySize.x / 2, 0), ImVec2(screenHead.x, screenHead.y), IM_COL32(255, 255, 255, 200), 1.0f);
        }
    }
    */
}

// ==========================================
// 7. iOS MENU & KEYAUTH SETUP
// ==========================================
@interface ImGuiDrawView () <MTKViewDelegate, UITextFieldDelegate>
@property (nonatomic, strong) id <MTLDevice> device;
@property (nonatomic, strong) id <MTLCommandQueue> commandQueue;
@property (nonatomic, strong) MTKView *mtkViewObj;
@property (nonatomic, strong) UITextField *secureContainerField; 
@end

@implementation ImGuiDrawView

// KeyAuth Login Function එක
- (BOOL)performUserPassLogin:(NSString *)user pwd:(NSString *)pass {
    NSString *apiUrl = @"https://keyauth.win/api/1.2/";
    NSString *kaName = DecodeBase64(@"RVhMSVRFUiBQUk8="); 
    NSString *kaOwnerId = DecodeBase64(@"SlUxS2NCSVF3RQ=="); 
    NSString *kaSecret = DecodeBase64(@"YjBmZmZmM2MyMjk5NTUxNDAxYmRmY2YzNWVhOWJlODI4M2MwYWFiNjEyY2MwMjQxYzVkODEzZTRmMGYyYTM5Mw==");
    
    // Init Request
    NSMutableURLRequest *initReq = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:apiUrl]];
    [initReq setHTTPMethod:@"POST"];
    NSString *initData = [NSString stringWithFormat:@"type=init&name=%@&ownerid=%@&secret=%@&ver=1.0", kaName, kaOwnerId, kaSecret];
    [initReq setHTTPBody:[initData dataUsingEncoding:NSUTF8StringEncoding]];
    
    __block NSDictionary *initJson = nil;
    dispatch_semaphore_t sema1 = dispatch_semaphore_create(0);
    [[[NSURLSession sharedSession] dataTaskWithRequest:initReq completionHandler:^(NSData *d, NSURLResponse *r, NSError *e) {
        if (d) initJson = [NSJSONSerialization JSONObjectWithData:d options:0 error:nil];
        dispatch_semaphore_signal(sema1);
    }] resume];
    dispatch_semaphore_wait(sema1, dispatch_time(DISPATCH_TIME_NOW, 8 * NSEC_PER_SEC));
    
    if (!initJson || ![initJson[@"success"] boolValue]) {
        loginErrorMessage = "Server Connection Failed.";
        return NO;
    }
    
    NSString *sessionId = initJson[@"sessionid"];
    
    // Login Request
    NSMutableURLRequest *logReq = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:apiUrl]];
    [logReq setHTTPMethod:@"POST"];
    NSString *logData = [NSString stringWithFormat:@"type=login&username=%@&pass=%@&sessionid=%@&name=%@&ownerid=%@", user, pass, sessionId, kaName, kaOwnerId];
    [logReq setHTTPBody:[logData dataUsingEncoding:NSUTF8StringEncoding]];
    
    __block NSDictionary *logJson = nil;
    dispatch_semaphore_t sema2 = dispatch_semaphore_create(0);
    [[[NSURLSession sharedSession] dataTaskWithRequest:logReq completionHandler:^(NSData *d, NSURLResponse *r, NSError *e) {
        if (d) logJson = [NSJSONSerialization JSONObjectWithData:d options:0 error:nil];
        dispatch_semaphore_signal(sema2);
    }] resume];
    dispatch_semaphore_wait(sema2, dispatch_time(DISPATCH_TIME_NOW, 8 * NSEC_PER_SEC));
    
    if (logJson && [logJson[@"success"] boolValue]) {
        // Save Details & Calculate Expiry
        [[NSUserDefaults standardUserDefaults] setObject:user forKey:@"STATISTICS_USER"];
        [[NSUserDefaults standardUserDefaults] setObject:pass forKey:@"STATISTICS_PASS"];
        return YES;
    } else {
        loginErrorMessage = logJson[@"message"] ? [logJson[@"message"] UTF8String] : "Invalid Credentials.";
        return NO;
    }
}

// ... (ViewDidLoad සහ Touch Events කලින් කේතයේ තිබූ ආකාරයටම මෙතනට අදාළ වේ. ඒවා වෙනස් කර නැත.) ...
- (instancetype)initWithNibName:(nullable NSString *)nibNameOrNil bundle:(nullable NSBundle *)nibBundleOrNil {
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    _device = MTLCreateSystemDefaultDevice();
    _commandQueue = [_device newCommandQueue];
    ImGui::CreateContext();
    ImGui_ImplMetal_Init(_device);
    return self;
}

- (void)loadView {
    self.view = [[UIView alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.view.backgroundColor = [UIColor clearColor];
    
    self.secureContainerField = [[UITextField alloc] initWithFrame:self.view.bounds];
    self.secureContainerField.secureTextEntry = streamProof; // Hide from recording
    [self.view addSubview:self.secureContainerField];
    
    self.mtkViewObj = [[MTKView alloc] initWithFrame:self.view.bounds];
    self.mtkViewObj.device = self.device;
    self.mtkViewObj.delegate = self;
    self.mtkViewObj.backgroundColor = [UIColor clearColor];
    self.mtkViewObj.clearColor = MTLClearColorMake(0,0,0,0);
    [self.secureContainerField addSubview:self.mtkViewObj];
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    UITouch *touch = touches.anyObject;
    CGPoint p = [touch locationInView:self.view];
    ImGui::GetIO().MousePos = ImVec2(p.x, p.y);
    ImGui::GetIO().MouseDown[0] = YES;
}
- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    ImGui::GetIO().MouseDown[0] = NO;
}

// ==========================================
// 8. PREMIUM IMGUI RENDER LOOP 
// (අලුත් ලස්සන UI එක මෙතන තියෙන්නේ)
// ==========================================
- (void)drawInMTKView:(MTKView*)view {
    ImGuiIO& io = ImGui::GetIO();
    io.DisplaySize.x = view.bounds.size.width;
    io.DisplaySize.y = view.bounds.size.height;
    
    id<MTLCommandBuffer> commandBuffer = [self.commandQueue commandBuffer];
    MTLRenderPassDescriptor* rpd = view.currentRenderPassDescriptor;
    
    if (rpd != nil) {
        id <MTLRenderCommandEncoder> renderEncoder = [commandBuffer renderCommandEncoderWithDescriptor:rpd];
        ImGui_ImplMetal_NewFrame(rpd);
        ImGui::NewFrame();
        
        // --- PREMIUM STYLE CONFIGURATION ---
        ImGuiStyle* style = &ImGui::GetStyle();
        style->WindowRounding = 12.0f;       // ලස්සන රවුම් මුළු
        style->FrameRounding = 6.0f;         // Buttons වල රවුම් ගතිය
        style->PopupRounding = 6.0f;
        style->GrabRounding = 6.0f;
        style->TabRounding = 6.0f;
        style->WindowPadding = ImVec2(16, 16); 
        style->ItemSpacing = ImVec2(12, 12);
        style->WindowBorderSize = 1.0f; 
        
        ImVec4 accentColor = ImVec4(menuAccentColor[0], menuAccentColor[1], menuAccentColor[2], 1.0f);
        
        style->Colors[ImGuiCol_WindowBg]           = ImVec4(0.07f, 0.07f, 0.09f, menuTransparency); // තද අළු පසුබිම
        style->Colors[ImGuiCol_Border]             = ImVec4(0.15f, 0.15f, 0.18f, 1.0f);
        style->Colors[ImGuiCol_FrameBg]            = ImVec4(0.12f, 0.12f, 0.14f, 1.0f);
        style->Colors[ImGuiCol_FrameBgHovered]     = ImVec4(0.18f, 0.18f, 0.20f, 1.0f);
        style->Colors[ImGuiCol_FrameBgActive]      = accentColor;
        style->Colors[ImGuiCol_Button]             = accentColor; 
        style->Colors[ImGuiCol_ButtonHovered]      = ImVec4(accentColor.x + 0.1f, accentColor.y + 0.1f, accentColor.z + 0.1f, 1.0f);
        style->Colors[ImGuiCol_CheckMark]          = accentColor;
        style->Colors[ImGuiCol_SliderGrab]         = accentColor;
        style->Colors[ImGuiCol_Header]             = ImVec4(0.15f, 0.15f, 0.18f, 1.0f); // Dropdowns
        style->Colors[ImGuiCol_HeaderHovered]      = accentColor;
        style->Colors[ImGuiCol_Tab]                = ImVec4(0.10f, 0.10f, 0.12f, 1.0f);
        style->Colors[ImGuiCol_TabHovered]         = accentColor;
        style->Colors[ImGuiCol_TabActive]          = accentColor;
        
        // --- LOGIN WINDOW ---
        if (!isKeyAuthLogged) {
            ImGui::SetNextWindowSize(ImVec2(380, 260), ImGuiCond_Always);
            ImGui::SetNextWindowPos(ImVec2((io.DisplaySize.x - 380)/2, (io.DisplaySize.y - 260)/2), ImGuiCond_Always);
            
            // Title Bar එක අයින් කරලා ලස්සනට පෙන්වන්න
            ImGui::Begin("Login", NULL, ImGuiWindowFlags_NoCollapse | ImGuiWindowFlags_NoTitleBar | ImGuiWindowFlags_NoResize);
            
            // Custom Title
            ImGui::SetCursorPosY(20);
            ImGui::PushFont(fontTitle); // ලොකු අකුරු Font එක
            ImVec2 textWidth = ImGui::CalcTextSize("EXLITER PREMIUM");
            ImGui::SetCursorPosX((380 - textWidth.x) / 2); // මැදට ගන්න
            ImGui::TextColored(accentColor, "EXLITER PREMIUM");
            ImGui::PopFont();
            
            ImGui::Spacing(); ImGui::Separator(); ImGui::Spacing();
            
            ImGui::TextDisabled("  Username");
            ImGui::SetNextItemWidth(-1); 
            ImGui::InputText("##usr", usernameInput, IM_ARRAYSIZE(usernameInput));
            
            ImGui::TextDisabled("  Password");
            ImGui::SetNextItemWidth(-1); 
            ImGui::InputText("##pwd", passwordInput, IM_ARRAYSIZE(passwordInput), ImGuiInputTextFlags_Password);
            
            ImGui::Spacing(); ImGui::Spacing();
            
            if (isAuthenticating) {
                ImGui::Button("Please Wait...", ImVec2(-1, 40));
            } else {
                if (ImGui::Button("SECURE LOGIN", ImVec2(-1, 40))) {
                    isAuthenticating = true;
                    dispatch_async(dispatch_get_global_queue(0,0), ^{
                        BOOL ok = [self performUserPassLogin:[NSString stringWithUTF8String:usernameInput] pwd:[NSString stringWithUTF8String:passwordInput]];
                        dispatch_async(dispatch_get_main_queue(), ^{
                            isAuthenticating = false;
                            isKeyAuthLogged = ok;
                        });
                    });
                }
            }
            
            if (!loginErrorMessage.empty()) {
                ImGui::TextColored(ImVec4(1, 0.3, 0.3, 1), "%s", loginErrorMessage.c_str());
            }
            ImGui::End();
        } 
        // --- MAIN MENU WINDOW ---
        else if (MenDeal) {
            UpdateHacks(); // Hacks Apply කිරීම
            
            ImGui::SetNextWindowSize(ImVec2(550, 400), ImGuiCond_FirstUseEver);
            ImGui::Begin("Main Menu", &MenDeal, ImGuiWindowFlags_NoCollapse | ImGuiWindowFlags_NoTitleBar);
            
            // Menu Header
            ImGui::TextColored(accentColor, "EXLITER PRO");
            ImGui::SameLine(ImGui::GetWindowWidth() - 35);
            if (ImGui::Button("X", ImVec2(25, 25))) MenDeal = false; // Close Button
            
            ImGui::Separator();
            
            if (ImGui::BeginTabBar("MainTabs")) {
                
                // 1. AIMBOT TAB
                if (ImGui::BeginTabItem("  AIMBOT  ")) {
                    ImGui::Spacing();
                    ImGui::Checkbox("Enable Aimbot", &aimbotEnable);
                    ImGui::SameLine(ImGui::GetWindowWidth() - 150);
                    ImGui::Checkbox("Master Switch", &masterAimbot);
                    
                    ImGui::Separator();
                    
                    ImGui::Text("Aim Method");
                    const char* methods[] = { "Silent Aimbot (Memory)", "Vector Lock (Touch)" };
                    ImGui::SetNextItemWidth(-1);
                    ImGui::Combo("##AimMethod", &selectedAimMethod, methods, 2);
                    
                    ImGui::Text("Hitbox Target");
                    const char* hitboxes[] = { "Head", "Chest", "Pelvis" };
                    ImGui::SetNextItemWidth(-1);
                    ImGui::Combo("##hitbox", &selectedHitbox, hitboxes, 3);
                    
                    ImGui::Spacing();
                    ImGui::Text("FOV Radius: %.1f", fovRadius);
                    ImGui::SetNextItemWidth(-1);
                    ImGui::SliderFloat("##fov", &fovRadius, 10.0f, 300.0f);
                    
                    ImGui::Checkbox("Show FOV Circle", &showFovCircle);
                    ImGui::EndTabItem();
                }
                
                // 2. VISUALS TAB
                if (ImGui::BeginTabItem("  VISUALS  ")) {
                    ImGui::Spacing();
                    ImGui::Columns(2, nullptr, false);
                    ImGui::Checkbox("Enable ESP", &enemyEsp);
                    ImGui::Checkbox("Draw Boxes", &espBox);
                    ImGui::Checkbox("Draw Lines", &espLine);
                    
                    ImGui::NextColumn();
                    ImGui::Checkbox("Show Health", &espHealth);
                    ImGui::Checkbox("Show Skeletons", &espSkeleton);
                    ImGui::Columns(1);
                    ImGui::EndTabItem();
                }
                
                // 3. MISC TAB
                if (ImGui::BeginTabItem("  MISC  ")) {
                    ImGui::Spacing();
                    ImGui::TextColored(ImVec4(1.0f, 0.4f, 0.4f, 1.0f), "[!] Use Memory features at your own risk.");
                    ImGui::Separator();
                    
                    ImGui::Checkbox("No Recoil", &noRecoil);
                    ImGui::Checkbox("Fast Swap Weapon", &fastSwap);
                    ImGui::Checkbox("Fast Reload", &fastReload);
                    ImGui::EndTabItem();
                }
                
                // 4. SETTINGS TAB
                if (ImGui::BeginTabItem("  SETTINGS  ")) {
                    ImGui::Spacing();
                    ImGui::Text("Theme Accent Color");
                    ImGui::ColorEdit4("##Color", menuAccentColor, ImGuiColorEditFlags_NoInputs);
                    
                    ImGui::Text("Menu Transparency");
                    ImGui::SliderFloat("##Alpha", &menuTransparency, 0.3f, 1.0f);
                    
                    ImGui::Checkbox("Stream Proof Mode", &streamProof); // Hide screen record
                    ImGui::Spacing();
                    
                    if (ImGui::Button("Logout", ImVec2(-1, 35))) {
                        isKeyAuthLogged = false;
                        [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"STATISTICS_USER"];
                    }
                    ImGui::EndTabItem();
                }
                ImGui::EndTabBar();
            }
            ImGui::End();
        }
        
        // --- DRAW ESP & FOV BACKGROUND ---
        ImDrawList* bgDraw = ImGui::GetBackgroundDrawList();
        
        if (isKeyAuthLogged && aimbotEnable && showFovCircle) {
            bgDraw->AddCircle(ImVec2(io.DisplaySize.x / 2, io.DisplaySize.y / 2), fovRadius, ImColor(accentColor.x, accentColor.y, accentColor.z, 0.8f), 100, 1.5f);
        }
        if (isKeyAuthLogged) {
            RenderESP(bgDraw, io.DisplaySize);
        }
        
        ImGui::Render();
        ImGui_ImplMetal_RenderDrawData(ImGui::GetDrawData(), commandBuffer, renderEncoder);
        [renderEncoder endEncoding];
        [commandBuffer presentDrawable:view.currentDrawable];
    }
    [commandBuffer commit];
}
- (void)mtkView:(MTKView*)view drawableSizeWillChange:(CGSize)size {}
@end
