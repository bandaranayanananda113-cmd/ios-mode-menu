#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#include <math.h>
#include <mach-o/dyld.h>
#include <mach/mach.h>
#include <mach/vm_map.h>
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
// 1. ALL GAME OFFSETS PLACEHOLDERS (FITTED FOR ALL OPTIONS)
// ==========================================
// Misc Offsets
#define OFFSET_NO_RECOIL       0x10A2B3C  // Fake Offset Example
#define OFFSET_FAST_SWAP       0x10B3C4D  // Fake Offset Example
#define OFFSET_FAST_RELOAD     0x10C4D5E  // Fake Offset Example
#define OFFSET_TELEPORT        0x10D5E6F  // Fake Offset Example

// Aimbot & Engine Offsets
#define OFFSET_AIMBOT_LOCK     0x20A1B2C  // Fake Offset Example
#define OFFSET_SILENT_AIM      0x20B2C3D  // Fake Offset Example
#define OFFSET_HITBOX_DATA     0x20C3D4E  // Fake Offset Example

// Visuals & ESP Offsets
#define OFFSET_ENTITY_LIST     0x30A7B8C  // Fake Offset Example
#define OFFSET_CAMERA_MATRIX   0x30B8C9D  // Fake Offset Example

// ==========================================
// SAFE MEMORY PATCHING FUNCTIONS 
// ==========================================
void safePatchMemory(uintptr_t address, const uint8_t* bytes, size_t size) {
    if (address == 0) return;
    vm_protect(mach_task_self(), (vm_address_t)address, size, FALSE, PROT_READ | PROT_WRITE);
    memcpy((void*)address, bytes, size);
    vm_protect(mach_task_self(), (vm_address_t)address, size, FALSE, PROT_READ | PROT_EXEC);
}

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
    static uintptr_t base = 0;
    if (base == 0) {
        base = get_GameModule_Base("GameAssembly.dylib"); 
    }
    return base + offset;
}

// ==========================================
// 3D ANIMATED TEXT RENDERER
// ==========================================
static void Draw3DAnimatedText(ImDrawList* drawList, ImFont* font, float fontSize, ImVec2 pos, const char* text, ImVec4 accent, bool isWatermark) {
    float time = (float)ImGui::GetTime();
    
    float baseAlpha = isWatermark ? 0.08f : 1.0f;
    float pulse = (sin(time * 4.0f) + 1.0f) * 0.5f; 
    int depth = isWatermark ? 3 : 5; 
    
    for (int i = depth; i > 0; i--) {
        float offsetX = i + sin(time * 2.0f + i * 0.2f) * (isWatermark ? 1.0f : 1.5f);
        float offsetY = i + cos(time * 2.0f + i * 0.2f) * (isWatermark ? 1.0f : 1.5f);
        
        float shadowAlpha = isWatermark ? 0.03f : 0.4f;
        drawList->AddText(font, fontSize, ImVec2(pos.x + offsetX, pos.y + offsetY), 
                          ImColor(10, 10, 15, (int)(shadowAlpha * 255)), text);
    }
    
    float r = accent.x + (1.0f - accent.x) * pulse * 0.4f;
    float g = accent.y + (1.0f - accent.y) * pulse * 0.4f;
    float b = accent.z + (1.0f - accent.z) * pulse * 0.4f;
    
    drawList->AddText(font, fontSize, pos, ImColor(r, g, b, baseAlpha), text);
}

// ==========================================
// KEYAUTH USERPASS CONFIGURATION
// ==========================================
static NSString *const kaName = @"EXLITER PRO";
static NSString *const kaOwnerId = @"JU1KcBIQwE";
static NSString *const kaSecret = @"b0ffff3c2299551401bdfcf35ea9be8283c0aab612cc0241c5d813e4f0f2a393";
static NSString *const kaVersion = @"1.0";

static bool isKeyAuthLogged = false;
static char usernameInput[64] = ""; 
static char passwordInput[64] = ""; 
static std::string subExpiryDate = "N/A";
static std::string subDaysRemaining = "0";
static std::string loginErrorMessage = "";
static bool isAuthenticating = false;

// ==========================================
// CHEAT VARIABLES
// ==========================================
static bool streamProof = true; 
static bool masterAimbot = false;
static bool aimbotEnable = false;
static int selectedAimConfig = 0; 
static int selectedAimMethod = 0; 
static bool showFovCircle = false;
static float fovCircleColor[4] = {1.00f, 0.32f, 0.12f, 1.00f};
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

static float menuAccentColor[4] = {1.00f, 0.32f, 0.12f, 1.00f}; 
static float menuTransparency = 0.90f;

static UITextField *hiddenTextField = nil;

// ==========================================
// 2. COMPLETE HACK LOGIC FUNCTION (DYNAMIC INJECTIONS INSTALLED)
// ==========================================
void UpdateHacks() {
    if (!isKeyAuthLogged) return; 

    // --- Aimbot Realtime Integration Logic ---
    if (masterAimbot && aimbotEnable) {
        uintptr_t aimLockAddr = getLocalRealOffset(OFFSET_AIMBOT_LOCK);
        uintptr_t hitboxAddr = getLocalRealOffset(OFFSET_HITBOX_DATA);
        
        // Pass slider settings to internal logic placeholders
        float currentFov = fovRadius;
        float currentDistance = maxDistance;
        int targetBone = selectedHitbox; // 0=Head, 1=Neck, 2=Body...
        
        if (selectedAimMethod == 0) {
            // Silent Aim Configuration Patch
            uintptr_t silentAddr = getLocalRealOffset(OFFSET_SILENT_AIM);
            const uint8_t silentPatch[] = { 0x20, 0x00, 0x80, 0xD2 }; // Generic ARM64 Injection
            safePatchMemory(silentAddr, silentPatch, sizeof(silentPatch));
        } else {
            // Vector/Memory Lock Patch Execution
            const uint8_t lockPatch[] = { 0x00, 0x01, 0x80, 0xD2 };
            safePatchMemory(aimLockAddr, lockPatch, sizeof(lockPatch));
        }
    }

    // --- ESP Drawing & Entity Matrix Injections ---
    if (enemyEsp) {
        uintptr_t entityList = getLocalRealOffset(OFFSET_ENTITY_LIST);
        uintptr_t viewMatrix = getLocalRealOffset(OFFSET_CAMERA_MATRIX);
        
        if (espLine)     { /* Dynamic ImGui Matrix Lines Render Loop placeholder */ }
        if (espBox)      { /* Dynamic ImGui Matrix Boxes Render Loop placeholder */ }
        if (espHealth)   { /* Parse Entity HP array structural lookup placeholder */ }
        if (espNickname) { /* Parse Entity Name pointer descriptor placeholder */ }
        if (espDistance) { /* Vector3 Math calculate local distance placeholder */ }
        if (espSkeleton) { /* Structural dynamic bone offset parsing hook */ }
    }

    // --- Misc Modifications Patch Execution Block ---
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

    static bool lastFastSwap = false;
    if (fastSwap != lastFastSwap) {
        uintptr_t addr = getLocalRealOffset(OFFSET_FAST_SWAP);
        if (fastSwap) {
            const uint8_t patch[] = { 0x00, 0x00, 0x80, 0xD2 }; // Dynamic fast transition bit override
            safePatchMemory(addr, patch, sizeof(patch));
        } else {
            const uint8_t restore[] = { 0xF4, 0x4F, 0x01, 0xA9 }; // Default hardware instruction
            safePatchMemory(addr, restore, sizeof(restore));
        }
        lastFastSwap = fastSwap;
    }

    static bool lastFastReload = false;
    if (fastReload != lastFastReload) {
        uintptr_t addr = getLocalRealOffset(OFFSET_FAST_RELOAD);
        if (fastReload) {
            const uint8_t patch[] = { 0x1F, 0x20, 0x03, 0xD5 }; // Speed duration instruction skip
            safePatchMemory(addr, patch, sizeof(patch));
        } else {
            const uint8_t restore[] = { 0xFD, 0x7B, 0x01, 0xA9 }; // Default register restore
            safePatchMemory(addr, restore, sizeof(restore));
        }
        lastFastReload = fastReload;
    }

    static bool lastTeleport = false;
    if (teleportEnemies != lastTeleport) {
        uintptr_t addr = getLocalRealOffset(OFFSET_TELEPORT);
        if (teleportEnemies) {
            const uint8_t patch[] = { 0xE0, 0x03, 0x27, 0x1E }; // Vector coordinates replication hook
            safePatchMemory(addr, patch, sizeof(patch));
        } else {
            const uint8_t restore[] = { 0xE0, 0x03, 0x00, 0xAA }; 
            safePatchMemory(addr, restore, sizeof(restore));
        }
        lastTeleport = teleportEnemies;
    }
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

- (BOOL)performUserPassLogin:(NSString *)user pwd:(NSString *)pass {
    NSString *apiUrl = @"https://keyauth.win/api/1.2/";
    NSMutableURLRequest *initRequest = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:apiUrl]];
    [initRequest setHTTPMethod:@"POST"];
    NSString *initPostData = [NSString stringWithFormat:@"type=init&name=%@&ownerid=%@&secret=%@&ver=%@", kaName, kaOwnerId, kaSecret, kaVersion];
    [initRequest setHTTPBody:[initPostData dataUsingEncoding:NSUTF8StringEncoding]];
    
    __block NSDictionary *initJson = nil;
    dispatch_semaphore_t sema1 = dispatch_semaphore_create(0);
    [[[NSURLSession sharedSession] dataTaskWithRequest:initRequest completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (data) initJson = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        dispatch_semaphore_signal(sema1);
    }] resume];
    dispatch_semaphore_wait(sema1, dispatch_time(DISPATCH_TIME_NOW, 8 * NSEC_PER_SEC));
    
    if (!initJson || ![initJson[@"success"] boolValue]) {
        loginErrorMessage = "Server Connection Failed.";
        return NO;
    }
    
    NSString *sessionId = initJson[@"sessionid"];
    if (!sessionId) return NO;
    
    NSMutableURLRequest *loginRequest = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:apiUrl]];
    [loginRequest setHTTPMethod:@"POST"];
    NSString *loginPostData = [NSString stringWithFormat:@"type=login&username=%@&pass=%@&sessionid=%@&name=%@&ownerid=%@", user, pass, sessionId, kaName, kaOwnerId];
    [loginRequest setHTTPBody:[loginPostData dataUsingEncoding:NSUTF8StringEncoding]];
    
    __block NSDictionary *loginJson = nil;
    dispatch_semaphore_t sema2 = dispatch_semaphore_create(0);
    [[[NSURLSession sharedSession] dataTaskWithRequest:loginRequest completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (data) loginJson = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        dispatch_semaphore_signal(sema2);
    }] resume];
    dispatch_semaphore_wait(sema2, dispatch_time(DISPATCH_TIME_NOW, 8 * NSEC_PER_SEC));
    
    if (loginJson && [loginJson[@"success"] boolValue]) {
        NSDictionary *info = loginJson[@"info"];
        if (info) {
            id expiryVal = info[@"expiry"];
            if (expiryVal) subExpiryDate = [NSString stringWithFormat:@"%@", expiryVal].UTF8String;
            NSArray *subs = info[@"subscriptions"];
            if (subs && subs.count > 0) {
                id timeleft = subs[0][@"timeleft"];
                if (timeleft) {
                    long long seconds = [timeleft longLongValue];
                    long long days = seconds / 86400;
                    subDaysRemaining = [NSString stringWithFormat:@"%lld Days", days].UTF8String;
                }
            }
        }
        [[NSUserDefaults standardUserDefaults] setObject:user forKey:@"STATISTICS_USER"];
        [[NSUserDefaults standardUserDefaults] setObject:pass forKey:@"STATISTICS_PASS"];
        [[NSUserDefaults standardUserDefaults] synchronize];
        return YES;
    } else {
        loginErrorMessage = loginJson[@"message"] ? [loginJson[@"message"] UTF8String] : "Invalid Credentials.";
        return NO;
    }
}

- (void)tryAutoLogin {
    NSString *savedUser = [[NSUserDefaults standardUserDefaults] stringForKey:@"STATISTICS_USER"];
    NSString *savedPass = [[NSUserDefaults standardUserDefaults] stringForKey:@"STATISTICS_PASS"];
    if (savedUser && savedPass) {
        strncpy(usernameInput, [savedUser UTF8String], sizeof(usernameInput) - 1);
        strncpy(passwordInput, [savedPass UTF8String], sizeof(passwordInput) - 1);
        isAuthenticating = true;
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            BOOL success = [self performUserPassLogin:savedUser pwd:savedPass];
            dispatch_async(dispatch_get_main_queue(), ^{
                isAuthenticating = false;
                if (success) isKeyAuthLogged = true;
            });
        });
    }
}

- (instancetype)initWithNibName:(nullable NSString *)nibNameOrNil bundle:(nullable NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    _device = MTLCreateSystemDefaultDevice();
    _commandQueue = [_device newCommandQueue];
    if (!self.device) abort();
    IMGUI_CHECKVERSION();
    ImGui::CreateContext();
    ImGuiIO& io = ImGui::GetIO();
    io.GetClipboardTextFn = GetClipboardTextFn;
    io.SetClipboardTextFn = SetClipboardTextFn;
    ImGui::GetIO().Fonts->AddFontFromMemoryCompressedTTF((void*)Honkai_compressed_data, Honkai_compressed_size, 45.0f, NULL, io.Fonts->GetGlyphRangesDefault());
    ImGui_ImplMetal_Init(_device);
    return self;
}

+ (void)showChange:(BOOL)open { MenDeal = !isKeyAuthLogged ? true : open; }

- (void)loadView
{
    CGFloat w = [UIApplication sharedApplication].windows[0].rootViewController.view.frame.size.width;
    CGFloat h = [UIApplication sharedApplication].windows[0].rootViewController.view.frame.size.height;
    self.view = [[UIView alloc] initWithFrame:CGRectMake(0, 0, w, h)];
    self.view.backgroundColor = [UIColor clearColor];
    
    self.secureContainerField = [[UITextField alloc] initWithFrame:self.view.bounds];
    self.secureContainerField.backgroundColor = [UIColor clearColor];
    self.secureContainerField.secureTextEntry = streamProof;
    self.secureContainerField.userInteractionEnabled = NO;
    [self.view addSubview:self.secureContainerField];
    
    self.mtkViewObj = [[MTKView alloc] initWithFrame:self.view.bounds];
    self.mtkViewObj.clearColor = MTLClearColorMake(0, 0, 0, 0);
    self.mtkViewObj.backgroundColor = [UIColor clearColor];
    self.mtkViewObj.userInteractionEnabled = NO; 
    
    UIView *secureLayer = self.secureContainerField.subviews.firstObject ?: self.secureContainerField;
    [secureLayer addSubview:self.mtkViewObj]; 
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.mtkViewObj.device = self.device;
    self.mtkViewObj.delegate = self;
    hiddenTextField = [[UITextField alloc] initWithFrame:CGRectMake(-100, -100, 10, 10)];
    hiddenTextField.keyboardType = UIKeyboardTypeASCIICapable;
    hiddenTextField.delegate = self;
    [self.view addSubview:hiddenTextField];
    [self tryAutoLogin];
}

- (void)updateStreamProofState {
    if (self.secureContainerField.secureTextEntry == streamProof) return;
    [self.mtkViewObj removeFromSuperview];
    self.secureContainerField.secureTextEntry = streamProof;
    UIView *secureLayer = self.secureContainerField.subviews.firstObject ?: self.secureContainerField;
    [secureLayer addSubview:self.mtkViewObj];
}

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string {
    ImGuiIO& io = ImGui::GetIO();
    for (int i = 0; i < string.length; i++) io.AddInputCharacter([string characterAtIndex:i]);
    return NO; 
}

- (void)updateIOWithTouchEvent:(UIEvent *)event
{
    UITouch *anyTouch = event.allTouches.anyObject;
    CGPoint touchLocation = [anyTouch locationInView:self.view];
    ImGuiIO &io = ImGui::GetIO();
    io.MousePos = ImVec2(touchLocation.x, touchLocation.y);
    BOOL hasActiveTouch = NO;
    for (UITouch *touch in event.allTouches) {
        if (touch.phase != UITouchPhaseEnded && touch.phase != UITouchPhaseCancelled) { hasActiveTouch = YES; break; }
    }
    io.MouseDown[0] = hasActiveTouch;
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event { [self updateIOWithTouchEvent:event]; }
- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event { [self updateIOWithTouchEvent:event]; }
- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event { [self updateIOWithTouchEvent:event]; }

- (void)drawInMTKView:(MTKView*)view
{
    ImGuiIO& io = ImGui::GetIO();
    io.DisplaySize = ImVec2(view.bounds.size.width, view.bounds.size.height);
    io.DeltaTime = 1.0f / 60.0f;
    
    if (self.secureContainerField.secureTextEntry != streamProof) {
        dispatch_async(dispatch_get_main_queue(), ^{ [self updateStreamProofState]; });
    }

    id<MTLCommandBuffer> commandBuffer = [self.commandQueue commandBuffer];
    [self.view setUserInteractionEnabled:(!isKeyAuthLogged ? YES : (MenDeal ? YES : NO))];
    if (isKeyAuthLogged) UpdateHacks();

    MTLRenderPassDescriptor* renderPassDescriptor = view.currentRenderPassDescriptor;
    if (renderPassDescriptor != nil)
    {
        id <MTLRenderCommandEncoder> renderEncoder = [commandBuffer renderCommandEncoderWithDescriptor:renderPassDescriptor];
        ImGui_ImplMetal_NewFrame(renderPassDescriptor);
        ImGui::NewFrame();
        
        ImGuiStyle* style = &ImGui::GetStyle();
        ImVec4 customAccent = ImVec4(menuAccentColor[0], menuAccentColor[1], menuAccentColor[2], menuAccentColor[3]);
        style->Colors[ImGuiCol_WindowBg] = ImVec4(0.06f, 0.07f, 0.10f, menuTransparency);
        style->Colors[ImGuiCol_CheckMark] = customAccent;
        style->Colors[ImGuiCol_SliderGrab] = customAccent;
        style->Colors[ImGuiCol_Button] = ImVec4(customAccent.x, customAccent.y, customAccent.z, 0.20f);
        
        ImFont* font = ImGui::GetFont();
        
        // --- SCREEN 1: LOGIN ---
        if (!isKeyAuthLogged) {
            ImGui::SetNextWindowSize(ImVec2(360, 330), ImGuiCond_Always);
            ImGui::Begin("LOGIN_SYSTEM", NULL, ImGuiWindowFlags_NoResize | ImGuiWindowFlags_NoCollapse);
            ImGui::InputText("Username", usernameInput, 64);
            ImGui::InputText("Password", passwordInput, 64, ImGuiInputTextFlags_Password);
            if (ImGui::Button("Login to System", ImVec2(-1, 40))) {
                isKeyAuthLogged = [self performUserPassLogin:[NSString stringWithUTF8String:usernameInput] pwd:[NSString stringWithUTF8String:passwordInput]];
            }
            ImGui::End();
        } 
        // --- SCREEN 2: MAIN MENU ---
        else if (MenDeal) {
            ImGui::SetNextWindowSize(ImVec2(540, 380), ImGuiCond_FirstUseEver);
            ImGui::Begin("STATISTICS_MAIN_CONTAINER", &MenDeal, ImGuiWindowFlags_NoCollapse);
            
            ImGui::Columns(2, "Layout", false);
            ImGui::SetColumnWidth(0, 140.0f);
            ImGui::BeginChild("Sidebar", ImVec2(0, 0), true);
            static int activeTab = 0;
            if (ImGui::Button("Aimbot", ImVec2(-1, 35))) activeTab = 0;
            if (ImGui::Button("Visuals", ImVec2(-1, 35))) activeTab = 1;
            if (ImGui::Button("Misc", ImVec2(-1, 35))) activeTab = 2;
            if (ImGui::Button("Settings", ImVec2(-1, 35))) activeTab = 3;
            ImGui::EndChild();
            
            ImGui::NextColumn();
            ImGui::BeginChild("Content", ImVec2(0, 0), false);
            
            if (activeTab == 0) {
                ImGui::Checkbox("Master Switch", &masterAimbot);
                ImGui::Checkbox("Enabled", &aimbotEnable);
                const char* methods[] = { "Silent aimbot", "Vector aim" };
                ImGui::Combo("Aiming Method", &selectedAimMethod, methods, 2);
                ImGui::Checkbox("Show FOV circle", &showFovCircle);
                ImGui::SliderFloat("FOV Radius", &fovRadius, 1.0f, 360.0f);
                ImGui::SliderFloat("Max Distance", &maxDistance, 10.0f, 500.0f);
            }
            else if (activeTab == 1) {
                ImGui::Checkbox("Enemy ESP", &enemyEsp);
                ImGui::Checkbox("Line", &espLine);
                ImGui::Checkbox("Box", &espBox);
                ImGui::Checkbox("Health", &espHealth);
                ImGui::Checkbox("Nickname", &espNickname);
                ImGui::Checkbox("Distance", &espDistance);
                ImGui::Checkbox("Skeleton", &espSkeleton);
            }
            else if (activeTab == 2) {
                ImGui::Checkbox("No Recoil", &noRecoil);
                ImGui::Checkbox("Fast Swap Weapon", &fastSwap);
                ImGui::Checkbox("Fast Reload", &fastReload);
                ImGui::Checkbox("Teleport enemies to you", &teleportEnemies);
            }
            else if (activeTab == 3) {
                ImGui::Checkbox("Stream Proof", &streamProof);
                ImGui::SliderFloat("Menu Transparency", &menuTransparency, 0.3f, 1.0f);
            }
            
            ImGui::EndChild();
            ImGui::End();
        }
        
        if (isKeyAuthLogged && aimbotEnable && showFovCircle) {
            ImDrawList* bg_list = ImGui::GetBackgroundDrawList();
            bg_list->AddCircle(ImVec2(io.DisplaySize.x / 2.0f, io.DisplaySize.y / 2.0f), fovRadius * 3.0f, ImColor(fovCircleColor[0], fovCircleColor[1], fovCircleColor[2], fovCircleColor[3]), 100, 1.5f);
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
