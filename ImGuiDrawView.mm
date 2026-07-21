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
#define OFFSET_CAMERA_FOV      0x0000000
#define OFFSET_ESP_BONE        0x0000000

// ==========================================
// SAFE MEMORY PATCHING FUNCTIONS 
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
        base = get_GameModule_Base("GameAssembly.dylib"); 
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
// CLEAN SHADOW TEXT RENDERER (Replacing the ugly 3D text)
// ==========================================
static void DrawCleanShadowText(ImDrawList* drawList, ImVec2 pos, const char* text, ImVec4 color, float fontSize, ImFont* font) {
    ImGui::PushFont(font);
    // Draw Shadow
    drawList->AddText(ImVec2(pos.x + 1.5f, pos.y + 1.5f), ImColor(0, 0, 0, 200), text);
    // Draw Text
    drawList->AddText(pos, ImColor(color.x, color.y, color.z, color.w), text);
    ImGui::PopFont();
}

// ==========================================
// SECURE STRINGS (Basic Base64 decoder)
// ==========================================
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
static float fovCircleColor[4] = {0.45f, 0.28f, 0.85f, 1.00f}; // Default nice purple
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

// Modern Default Theme Colors
static float menuAccentColor[4] = {0.45f, 0.28f, 0.85f, 1.00f}; // Purple accent
static float menuTransparency = 0.95f;

static UITextField *hiddenTextField = nil;

// ==========================================
// 2. APPLY HACKS LOGIC (WITH HEX CODES)
// ==========================================
void UpdateHacks() {
    if (!isKeyAuthLogged) return; 

    // --- AIMBOT LOGIC ---
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
    }
    
    lastMasterAim = masterAimbot;
    lastAimEnable = aimbotEnable;
    lastAimMethod = selectedAimMethod;

    // --- MISC HACKS LOGIC ---
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
            const uint8_t patch[] = { 0x00, 0x00, 0x80, 0xD2 }; 
            safePatchMemory(addr, patch, sizeof(patch));
        } else {
            const uint8_t restore[] = { 0xF4, 0x4F, 0x01, 0xA9 }; 
            safePatchMemory(addr, restore, sizeof(restore));
        }
        lastFastSwap = fastSwap;
    }

    static bool lastFastReload = false;
    if (fastReload != lastFastReload) {
        uintptr_t addr = getLocalRealOffset(OFFSET_FAST_RELOAD);
        if (fastReload) {
            const uint8_t patch[] = { 0x1F, 0x20, 0x03, 0xD5 }; 
            safePatchMemory(addr, patch, sizeof(patch));
        } else {
            const uint8_t restore[] = { 0xFD, 0x7B, 0x01, 0xA9 }; 
            safePatchMemory(addr, restore, sizeof(restore));
        }
        lastFastReload = fastReload;
    }

    static bool lastTeleport = false;
    if (teleportEnemies != lastTeleport) {
        uintptr_t addr = getLocalRealOffset(OFFSET_TELEPORT);
        if (teleportEnemies) {
            const uint8_t patch[] = { 0xE0, 0x03, 0x27, 0x1E }; 
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
    
    NSString *kaName = DecodeBase64(@"RVhMSVRFUiBQUk8="); 
    NSString *kaOwnerId = DecodeBase64(@"SlUxS2NCSVF3RQ=="); 
    NSString *kaSecret = DecodeBase64(@"YjBmZmZmM2MyMjk5NTUxNDAxYmRmY2YzNWVhOWJlODI4M2MwYWFiNjEyY2MwMjQxYzVkODEzZTRmMGYyYTM5Mw==");
    NSString *kaVersion = @"1.0";
    
    NSMutableURLRequest *initRequest = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:apiUrl]];
    [initRequest setHTTPMethod:@"POST"];
    NSString *initPostData = [NSString stringWithFormat:@"type=init&name=%@&ownerid=%@&secret=%@&ver=%@", kaName, kaOwnerId, kaSecret, kaVersion];
    [initRequest setHTTPBody:[initPostData dataUsingEncoding:NSUTF8StringEncoding]];
    
    __block NSDictionary *initJson = nil;
    dispatch_semaphore_t sema1 = dispatch_semaphore_create(0);
    
    [[[NSURLSession sharedSession] dataTaskWithRequest:initRequest completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (data) { initJson = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil]; }
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
        if (data) { loginJson = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil]; }
        dispatch_semaphore_signal(sema2);
    }] resume];
    dispatch_semaphore_wait(sema2, dispatch_time(DISPATCH_TIME_NOW, 8 * NSEC_PER_SEC));
    
    if (loginJson && [loginJson[@"success"] boolValue]) {
        NSDictionary *info = loginJson[@"info"];
        if (info) {
            id expiryVal = info[@"expiry"];
            if (expiryVal) { subExpiryDate = [NSString stringWithFormat:@"%@", expiryVal].UTF8String; }
            NSArray *subs = info[@"subscriptions"];
            if (subs && subs.count > 0) {
                id timeleft = subs[0][@"timeleft"];
                if (timeleft) {
                    long long days = [timeleft longLongValue] / 86400;
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
                if (success) { isKeyAuthLogged = true; } 
                else {
                    [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"STATISTICS_USER"];
                    [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"STATISTICS_PASS"];
                    [[NSUserDefaults standardUserDefaults] synchronize];
                }
            });
        });
    }
}

- (instancetype)initWithNibName:(nullable NSString *)nibNameOrNil bundle:(nullable NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    _device = MTLCreateSystemDefaultDevice();
    _commandQueue = [_device newCommandQueue];

    if (!self.device) return nil;
    IMGUI_CHECKVERSION();
    ImGui::CreateContext();
    ImGuiIO& io = ImGui::GetIO(); (void)io;
    
    io.GetClipboardTextFn = GetClipboardTextFn;
    io.SetClipboardTextFn = SetClipboardTextFn;
    
    fontMain = io.Fonts->AddFontFromMemoryCompressedTTF((void*)Honkai_compressed_data, Honkai_compressed_size, 15.0f, NULL, io.Fonts->GetGlyphRangesDefault());
    fontTitle = io.Fonts->AddFontFromMemoryCompressedTTF((void*)Honkai_compressed_data, Honkai_compressed_size, 24.0f, NULL, io.Fonts->GetGlyphRangesDefault());
    
    ImGui_ImplMetal_Init(_device);
    return self;
}

+ (void)showChange:(BOOL)open {
    if (!isKeyAuthLogged) { MenDeal = true; } 
    else { MenDeal = open; }
}

- (void)loadView {
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
    self.mtkViewObj.clipsToBounds = YES;
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
    hiddenTextField.autocorrectionType = UITextAutocorrectionTypeNo;
    hiddenTextField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    hiddenTextField.delegate = self;
    [self.view addSubview:hiddenTextField];

    UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleLongPress:)];
    [self.view addGestureRecognizer:longPress];

    [self tryAutoLogin];
}

// ==========================================
// FULLY FIXED STREAM PROOF TOGGLE (Rebuilds the TextField)
// ==========================================
- (void)updateStreamProofState {
    if (self.secureContainerField.secureTextEntry == streamProof) {
        isStreamProofUpdating = false;
        return;
    }
    
    // Safely remove existing views
    [self.mtkViewObj removeFromSuperview];
    [self.secureContainerField removeFromSuperview];
    
    // Completely recreate the TextField to force iOS to apply the new secure layer state correctly
    self.secureContainerField = [[UITextField alloc] initWithFrame:self.view.bounds];
    self.secureContainerField.backgroundColor = [UIColor clearColor];
    self.secureContainerField.secureTextEntry = streamProof;
    self.secureContainerField.userInteractionEnabled = NO;
    [self.view addSubview:self.secureContainerField];
    
    // Re-attach MTKView
    UIView *secureLayer = self.secureContainerField.subviews.firstObject ?: self.secureContainerField;
    [secureLayer addSubview:self.mtkViewObj];
    
    isStreamProofUpdating = false;
}

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string {
    ImGuiIO& io = ImGui::GetIO();
    for (int i = 0; i < string.length; i++) { io.AddInputCharacter([string characterAtIndex:i]); }
    return NO; 
}

- (void)handleLongPress:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state == UIGestureRecognizerStateBegan) {
        ImGuiIO& io = ImGui::GetIO();
        if (io.WantTextInput) {
            UIMenuController *menu = [UIMenuController sharedMenuController];
            CGPoint location = [gesture locationInView:self.view];
            [menu setTargetRect:CGRectMake(location.x, location.y, 1, 1) inView:self.view];
            [menu setMenuVisible:YES animated:YES];
        }
    }
}

- (void)updateIOWithTouchEvent:(UIEvent *)event {
    UITouch *anyTouch = event.allTouches.anyObject;
    CGPoint touchLocation = [anyTouch locationInView:self.view];
    ImGuiIO &io = ImGui::GetIO();
    io.MousePos = ImVec2(touchLocation.x, touchLocation.y);

    BOOL hasActiveTouch = NO;
    for (UITouch *touch in event.allTouches) {
        if (touch.phase != UITouchPhaseEnded && touch.phase != UITouchPhaseCancelled) {
            hasActiveTouch = YES;
            break;
        }
    }
    io.MouseDown[0] = hasActiveTouch;
    
    if (anyTouch.phase == UITouchPhaseBegan) {
        if (!ImGui::IsAnyItemActive() && !ImGui::IsWindowHovered(ImGuiHoveredFlags_AnyWindow)) {
            [self.view endEditing:YES];
            [hiddenTextField resignFirstResponder];
        }
    }
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event { [self updateIOWithTouchEvent:event]; }
- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event { [self updateIOWithTouchEvent:event]; }
- (void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event { [self updateIOWithTouchEvent:event]; }
- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event { [self updateIOWithTouchEvent:event]; }

// ==========================================
// RENDER LOOP (MODERN CLEAN UI IMPLEMENTATION)
// ==========================================
- (void)drawInMTKView:(MTKView*)view {
    ImGuiIO& io = ImGui::GetIO();
    io.DisplaySize.x = view.bounds.size.width;
    io.DisplaySize.y = view.bounds.size.height;

    CGFloat framebufferScale = view.window.screen.scale ?: UIScreen.mainScreen.scale;
    io.DisplayFramebufferScale = ImVec2(framebufferScale, framebufferScale);
    io.DeltaTime = 1 / float(view.preferredFramesPerSecond ?: 120);
    
    static bool wasWantTextInput = false;
    if (io.WantTextInput && !wasWantTextInput) { [hiddenTextField becomeFirstResponder]; } 
    else if (!io.WantTextInput && wasWantTextInput) {
        [hiddenTextField resignFirstResponder];
        hiddenTextField.text = @""; 
    }
    wasWantTextInput = io.WantTextInput;

    if (self.secureContainerField.secureTextEntry != streamProof && !isStreamProofUpdating) {
        isStreamProofUpdating = true;
        dispatch_async(dispatch_get_main_queue(), ^{ [self updateStreamProofState]; });
    }

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
        
        // --- MODERN SLEEK THEME ---
        ImGuiStyle* style = &ImGui::GetStyle();
        style->WindowRounding = 8.0f;       
        style->FrameRounding = 5.0f;        
        style->GrabRounding = 5.0f;
        style->PopupRounding = 5.0f;
        style->ChildRounding = 5.0f;
        style->TabRounding = 5.0f;
        style->WindowPadding = ImVec2(15, 15); 
        style->FramePadding = ImVec2(8, 6);
        style->ItemSpacing = ImVec2(10, 12);
        style->WindowBorderSize = 1.0f; 
        style->FrameBorderSize = 0.0f;

        ImVec4* colors = style->Colors;
        colors[ImGuiCol_WindowBg]               = ImVec4(0.08f, 0.08f, 0.09f, menuTransparency); 
        colors[ImGuiCol_ChildBg]                = ImVec4(0.12f, 0.12f, 0.13f, 0.60f); 
        colors[ImGuiCol_FrameBg]                = ImVec4(0.15f, 0.15f, 0.17f, 1.00f); 
        colors[ImGuiCol_FrameBgHovered]         = ImVec4(0.19f, 0.19f, 0.21f, 1.00f);
        colors[ImGuiCol_FrameBgActive]          = ImVec4(0.22f, 0.22f, 0.25f, 1.00f);
        
        ImVec4 customAccent = ImVec4(menuAccentColor[0], menuAccentColor[1], menuAccentColor[2], menuAccentColor[3]);
        colors[ImGuiCol_Border]                 = ImVec4(customAccent.x, customAccent.y, customAccent.z, 0.60f); 
        colors[ImGuiCol_CheckMark]              = customAccent;
        colors[ImGuiCol_SliderGrab]             = customAccent;
        colors[ImGuiCol_SliderGrabActive]       = ImVec4(customAccent.x + 0.1f, customAccent.y + 0.1f, customAccent.z + 0.1f, 1.0f);
        colors[ImGuiCol_Button]                 = ImVec4(customAccent.x, customAccent.y, customAccent.z, 0.70f); 
        colors[ImGuiCol_ButtonHovered]          = ImVec4(customAccent.x, customAccent.y, customAccent.z, 0.90f);
        colors[ImGuiCol_ButtonActive]           = ImVec4(customAccent.x - 0.1f, customAccent.y - 0.1f, customAccent.z - 0.1f, 1.0f);
        
        // Tab Colors
        colors[ImGuiCol_Tab]                    = ImVec4(0.15f, 0.15f, 0.17f, 1.00f);
        colors[ImGuiCol_TabHovered]             = ImVec4(customAccent.x, customAccent.y, customAccent.z, 0.80f);
        colors[ImGuiCol_TabActive]              = customAccent;
        colors[ImGuiCol_TabUnfocused]           = ImVec4(0.15f, 0.15f, 0.17f, 1.00f);
        colors[ImGuiCol_TabUnfocusedActive]     = customAccent;

        colors[ImGuiCol_Text]                   = ImVec4(0.95f, 0.95f, 0.97f, 1.00f); 
        colors[ImGuiCol_TextDisabled]           = ImVec4(0.50f, 0.50f, 0.55f, 1.00f); 
        
        if (!isKeyAuthLogged) 
        {
            CGFloat loginWidth = 350;  
            CGFloat loginHeight = 250; 
            CGFloat lx = (view.bounds.size.width - loginWidth) / 2;
            CGFloat ly = (view.bounds.size.height - loginHeight) / 2;
            
            ImGui::SetNextWindowPos(ImVec2(lx, ly), ImGuiCond_Always);
            ImGui::SetNextWindowSize(ImVec2(loginWidth, loginHeight), ImGuiCond_Always);
            
            ImGuiWindowFlags login_flags = ImGuiWindowFlags_NoCollapse | ImGuiWindowFlags_NoTitleBar | ImGuiWindowFlags_NoResize | ImGuiWindowFlags_NoSavedSettings | ImGuiWindowFlags_NoMove;
            ImGui::Begin("LOGIN", NULL, login_flags);
            
            ImDrawList* drawList = ImGui::GetWindowDrawList();
            ImVec2 pos = ImGui::GetWindowPos();
            
            // Clean Top Header bar
            drawList->AddRectFilled(pos, ImVec2(pos.x + loginWidth, pos.y + 55), ImColor(18, 18, 22, 255), 8.0f, ImDrawFlags_RoundCornersTop);
            drawList->AddLine(ImVec2(pos.x, pos.y + 55), ImVec2(pos.x + loginWidth, pos.y + 55), ImColor(customAccent.x, customAccent.y, customAccent.z, 1.0f), 2.0f);
            
            DrawCleanShadowText(drawList, ImVec2(pos.x + 20, pos.y + 15), "EXLITER PRO", customAccent, 24.0f, fontTitle);
            
            ImGui::Dummy(ImVec2(0, 45)); 
            
            ImGui::TextDisabled("Username:");
            ImGui::SetNextItemWidth(260); 
            ImGui::InputText("##UserField", usernameInput, IM_ARRAYSIZE(usernameInput));
            ImGui::SameLine();
            if (ImGui::Button("C##1", ImVec2(35, 0))) { memset(usernameInput, 0, sizeof(usernameInput)); }
            
            ImGui::TextDisabled("Password:");
            ImGui::SetNextItemWidth(260); 
            ImGui::InputText("##PassField", passwordInput, IM_ARRAYSIZE(passwordInput), ImGuiInputTextFlags_Password);
            ImGui::SameLine();
            if (ImGui::Button("C##2", ImVec2(35, 0))) { memset(passwordInput, 0, sizeof(passwordInput)); }
            
            ImGui::Spacing(); ImGui::Separator(); ImGui::Spacing();
            
            if (isAuthenticating) {
                ImGui::Button("Authenticating Please Wait...", ImVec2(-1, 35));
            } else {
                if (ImGui::Button("Login to Menu", ImVec2(-1, 35))) {
                    NSString *uStr = [NSString stringWithUTF8String:usernameInput];
                    NSString *pStr = [NSString stringWithUTF8String:passwordInput];
                    if (uStr.length > 0 && pStr.length > 0) {
                        isAuthenticating = true;
                        loginErrorMessage = "";
                        [hiddenTextField resignFirstResponder];
                        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                            BOOL success = [self performUserPassLogin:uStr pwd:pStr];
                            dispatch_async(dispatch_get_main_queue(), ^{
                                isAuthenticating = false;
                                if (success) { isKeyAuthLogged = true; }
                            });
                        });
                    } else {
                        loginErrorMessage = "Credentials cannot be empty.";
                    }
                }
            }
            if (!loginErrorMessage.empty()) {
                ImGui::TextColored(ImVec4(1.0f, 0.4f, 0.4f, 1.0f), "%s", loginErrorMessage.c_str());
            }
            ImGui::End();
        } 
        
        else if (MenDeal == true) 
        {
            if ([hiddenTextField isFirstResponder]) { [hiddenTextField resignFirstResponder]; }

            CGFloat menuWidth = 480;  
            CGFloat menuHeight = 360; 
            CGFloat mx = (view.bounds.size.width - menuWidth) / 2;
            CGFloat my = (view.bounds.size.height - menuHeight) / 2;
            
            ImGui::SetNextWindowPos(ImVec2(mx, my), ImGuiCond_FirstUseEver);
            ImGui::SetNextWindowSize(ImVec2(menuWidth, menuHeight), ImGuiCond_FirstUseEver); 
            
            ImGuiWindowFlags window_flags = ImGuiWindowFlags_NoCollapse | ImGuiWindowFlags_NoTitleBar | ImGuiWindowFlags_NoResize | ImGuiWindowFlags_NoSavedSettings;
            ImGui::Begin("MAIN_MENU", &MenDeal, window_flags);
            
            ImDrawList* drawList = ImGui::GetWindowDrawList();
            ImVec2 pos = ImGui::GetWindowPos();
            
            // Clean Modern Header
            drawList->AddRectFilled(pos, ImVec2(pos.x + menuWidth, pos.y + 50), ImColor(18, 18, 22, 255), 8.0f, ImDrawFlags_RoundCornersTop);
            drawList->AddLine(ImVec2(pos.x, pos.y + 50), ImVec2(pos.x + menuWidth, pos.y + 50), ImColor(customAccent.x, customAccent.y, customAccent.z, 1.0f), 2.0f);
            
            DrawCleanShadowText(drawList, ImVec2(pos.x + 15, pos.y + 12), "EXLITER PRO", customAccent, 24.0f, fontTitle);
            
            ImGui::SetCursorPos(ImVec2(menuWidth - 40, 12));
            ImGui::PushStyleColor(ImGuiCol_Button, ImVec4(0,0,0,0));
            if (ImGui::Button("X", ImVec2(25, 25))) { MenDeal = false; }
            ImGui::PopStyleColor();

            ImGui::SetCursorPosY(55);
            ImGui::Spacing();
            
            // TAB SYSTEM (Replaced Columns)
            if (ImGui::BeginTabBar("MenuTabs")) {
                
                if (ImGui::BeginTabItem("Aimbot")) {
                    ImGui::Spacing();
                    ImGui::Checkbox("Master Switch", &masterAimbot);
                    ImGui::Separator();
                    
                    ImGui::Text("Configuration");
                    const char* aimConfigs[] = { "Global", "Legit", "Rage" };
                    ImGui::SetNextItemWidth(-1);
                    ImGui::Combo("##AimConfig", &selectedAimConfig, aimConfigs, IM_ARRAYSIZE(aimConfigs));
                    
                    ImGui::Checkbox("Enabled", &aimbotEnable);
                    
                    const char* aimMethods[] = { "Silent aimbot", "Vector aim" };
                    ImGui::SetNextItemWidth(-1);
                    ImGui::Combo("##AimMethod", &selectedAimMethod, aimMethods, IM_ARRAYSIZE(aimMethods));
                    
                    ImGui::Checkbox("Show FOV circle", &showFovCircle);
                    ImGui::SameLine(ImGui::GetWindowWidth() - 40); 
                    ImGui::ColorEdit4("##FovCircleColorPicker", fovCircleColor, ImGuiColorEditFlags_NoInputs | ImGuiColorEditFlags_AlphaBar | ImGuiColorEditFlags_PickerHueWheel);

                    ImGui::Checkbox("Ignore Knocked", &ignoreKnocked);
                    ImGui::Checkbox("Force lock", &forceLock);
                    
                    const char* hitboxes[] = { "Head", "Neck", "Body", "Randomized" };
                    ImGui::SetNextItemWidth(-1);
                    ImGui::Combo("##Hitbox", &selectedHitbox, hitboxes, IM_ARRAYSIZE(hitboxes));
                    
                    ImGui::Text("FOV"); ImGui::SameLine(ImGui::GetWindowWidth() - 60); ImGui::TextColored(customAccent, "%.1f°", fovRadius);
                    ImGui::SetNextItemWidth(-1);
                    ImGui::SliderFloat("##FOV_Slider", &fovRadius, 1.0f, 360.0f, "");
                    
                    ImGui::Text("Max distance"); ImGui::SameLine(ImGui::GetWindowWidth() - 70); ImGui::TextColored(customAccent, "%.1fm", maxDistance);
                    ImGui::SetNextItemWidth(-1);
                    ImGui::SliderFloat("##Dist_Slider", &maxDistance, 10.0f, 500.0f, "");
                    
                    if (selectedAimMethod == 0) {
                        ImGui::Text("Hit chance"); ImGui::SameLine(ImGui::GetWindowWidth() - 60); ImGui::TextColored(customAccent, "%.0f%%", hitChance);
                        ImGui::SetNextItemWidth(-1);
                        ImGui::SliderFloat("##Hit_Slider", &hitChance, 1.0f, 100.0f, "");
                    } else {
                        ImGui::Text("Lock speed"); ImGui::SameLine(ImGui::GetWindowWidth() - 50); ImGui::TextColored(customAccent, "%.1f", lockSpeed);
                        ImGui::SetNextItemWidth(-1);
                        ImGui::SliderFloat("##Lock_Slider", &lockSpeed, 1.0f, 20.0f, "");
                    }
                    ImGui::EndTabItem();
                }
                
                if (ImGui::BeginTabItem("Visuals")) {
                    ImGui::Spacing();
                    ImGui::Checkbox("Enemy ESP", &enemyEsp);
                    ImGui::Checkbox("Lines", &espLine);
                    ImGui::Checkbox("Boxes", &espBox);
                    ImGui::Checkbox("Health Bar", &espHealth);
                    ImGui::Checkbox("Nickname", &espNickname);
                    ImGui::Checkbox("Distance", &espDistance);
                    ImGui::Checkbox("Skeletons", &espSkeleton);
                    ImGui::Checkbox("Nearby Counter", &nearbyCount);
                    
                    ImGui::Spacing(); ImGui::Separator(); ImGui::Spacing();
                    ImGui::Text("Counter Text Size:");
                    ImGui::SetNextItemWidth(-1);
                    ImGui::SliderFloat("##CounterSize", &counterTextSize, 10.0f, 50.0f, "%.1fpx");
                    ImGui::EndTabItem();
                }
                
                if (ImGui::BeginTabItem("Misc")) {
                    ImGui::Spacing();
                    ImGui::TextColored(ImVec4(1.0f, 0.4f, 0.4f, 1.0f), "Warning: Some options may increase ban risk.");
                    ImGui::Spacing(); ImGui::Separator(); ImGui::Spacing();
                    
                    ImGui::Checkbox("No Recoil", &noRecoil);
                    ImGui::Checkbox("Fast Swap Weapon", &fastSwap);
                    ImGui::Checkbox("Fast Reload", &fastReload);
                    ImGui::Checkbox("Teleport Enemies", &teleportEnemies);
                    ImGui::EndTabItem();
                }
                
                if (ImGui::BeginTabItem("Settings")) {
                    ImGui::Spacing();
                    ImGui::TextDisabled("User:"); ImGui::SameLine(); ImGui::Text("%s", usernameInput);
                    ImGui::TextDisabled("Expiry:"); ImGui::SameLine(); ImGui::TextColored(customAccent, "%s", subDaysRemaining.c_str());
                    
                    ImGui::Spacing(); ImGui::Separator(); ImGui::Spacing();
                    
                    // Fixed Stream Proof Toggle
                    ImGui::Checkbox("Stream Proof (Hide Screen Recording)", &streamProof);
                    
                    ImGui::Spacing();
                    ImGui::Text("Menu Accent Color");
                    ImGui::SameLine(ImGui::GetWindowWidth() - 40);
                    ImGui::ColorEdit4("##ThemeAccentPicker", menuAccentColor, ImGuiColorEditFlags_NoInputs | ImGuiColorEditFlags_AlphaBar | ImGuiColorEditFlags_PickerHueWheel);
                    
                    ImGui::Text("Menu Transparency");
                    ImGui::SetNextItemWidth(-1);
                    ImGui::SliderFloat("##Transparency", &menuTransparency, 0.3f, 1.0f, "%.2f");
                    
                    ImGui::Spacing();
                    if (ImGui::Button("Logout Account", ImVec2(-1, 35))) {
                        [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"STATISTICS_USER"];
                        [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"STATISTICS_PASS"];
                        [[NSUserDefaults standardUserDefaults] synchronize];
                        isKeyAuthLogged = false;
                        memset(usernameInput, 0, sizeof(usernameInput));
                        memset(passwordInput, 0, sizeof(passwordInput));
                    }
                    ImGui::EndTabItem();
                }
                ImGui::EndTabBar();
            }
            ImGui::End();   
        }
        
        ImDrawList* draw_list = ImGui::GetBackgroundDrawList();
        
        if (isKeyAuthLogged && aimbotEnable && showFovCircle) {
            ImVec2 center = ImVec2(io.DisplaySize.x / 2.0f, io.DisplaySize.y / 2.0f);
            draw_list->AddCircle(center, fovRadius * 3.0f, ImColor(fovCircleColor[0], fovCircleColor[1], fovCircleColor[2], fovCircleColor[3]), 100, 1.2f);
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
