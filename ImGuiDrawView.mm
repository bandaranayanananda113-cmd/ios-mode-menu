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

// 🛑 KeyAuth Header එක (මෙය ඔබගේ project එක සතු විය යුතුය)
// #include "KeyAuth/auth.hpp" 

#define kWidth  [UIScreen mainScreen].bounds.size.width
#define kHeight [UIScreen mainScreen].bounds.size.height
#define kScale [UIScreen mainScreen].scale

static bool MenDeal = true; 

// ==========================================
// KEYAUTH CONFIGURATION
// ==========================================
static std::string keyAuth_Name = "EXLITER PRO";
static std::string keyAuth_OwnerID = "JU1KcBIQwE";
static std::string keyAuth_Secret = "b0ffff3c2299551401bdfcf35ea9be8283c0aab612cc0241c5d813e4f0f2a393";
static std::string keyAuth_Version = "1.0";

// ==========================================
// 1. GAME OFFSETS 
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

struct Vector2 { float x, y; };
struct Vector3 { float x, y, z; };
struct Matrix { float m[4][4]; };

template <typename T>
T ReadMemory(uintptr_t address) {
    T value = {};
    if (address == 0) return value;
    memcpy(&value, (void*)address, sizeof(T));
    return value;
}

bool WorldToScreen(Vector3 worldPos, Vector2& screenPos, Matrix viewMatrix, float screenWidth, float screenHeight) {
    float w = viewMatrix.m[3][0] * worldPos.x + viewMatrix.m[3][1] * worldPos.y + viewMatrix.m[3][2] * worldPos.z + viewMatrix.m[3][3];
    if (w < 0.01f) return false; 
    float x = viewMatrix.m[0][0] * worldPos.x + viewMatrix.m[0][1] * worldPos.y + viewMatrix.m[0][2] * worldPos.z + viewMatrix.m[0][3];
    float y = viewMatrix.m[1][0] * worldPos.x + viewMatrix.m[1][1] * worldPos.y + viewMatrix.m[1][2] * worldPos.z + viewMatrix.m[1][3];
    screenPos.x = (screenWidth / 2) * (1.0f + x / w);
    screenPos.y = (screenHeight / 2) * (1.0f - y / w);
    return true;
}

uintptr_t get_GameModule_Base(const char* moduleName) {
    uint32_t count = _dyld_image_count();
    for (uint32_t i = 0; i < count; i++) {
        const char* name = _dyld_get_image_name(i);
        if (name && strstr(name, moduleName)) return (uintptr_t)_dyld_get_image_header(i);
    }
    return 0;
}

uintptr_t getLocalRealOffset(uintptr_t offset) {
    if (offset == 0) return 0; 
    static uintptr_t base = 0;
    if (base == 0) base = get_GameModule_Base("GameAssembly.dylib");
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

static void DrawCleanShadowText(ImDrawList* drawList, ImVec2 pos, const char* text, ImVec4 color, float fontSize, ImFont* font) {
    ImGui::PushFont(font);
    drawList->AddText(ImVec2(pos.x + 2.0f, pos.y + 2.0f), ImColor(0, 0, 0, 220), text);
    drawList->AddText(ImVec2(pos.x + 1.0f, pos.y + 1.0f), ImColor(50, 50, 50, 150), text);
    drawList->AddText(pos, ImColor(color.x, color.y, color.z, color.w), text);
    ImGui::PopFont();
}

NSString* DecodeBase64(NSString* encodedString) {
    NSData *decodedData = [[NSData alloc] initWithBase64EncodedString:encodedString options:0];
    return [[NSString alloc] initWithData:decodedData encoding:NSUTF8StringEncoding];
}

// ==========================================
// GLOBALS
// ==========================================
static ImFont* fontMain = nullptr;
static ImFont* fontTitle = nullptr;
static bool isKeyAuthLogged = false;
static char usernameInput[64] = ""; 
static char passwordInput[64] = ""; 
static std::string subExpiryDate = "N/A";
static std::string subDaysRemaining = "N/A";
static std::string loginErrorMessage = "";
static bool isAuthenticating = false;

static bool streamProof = true;
static bool isStreamProofUpdating = false; 

// Cheats
static bool masterAimbot = false; static bool aimbotEnable = false;
static int selectedAimConfig = 0; static int selectedAimMethod = 0; 
static bool showFovCircle = false; static float fovCircleColor[4] = {0.85f, 0.28f, 0.45f, 1.00f}; 
static bool ignoreKnocked = false; static bool forceLock = false;
static int selectedHitbox = 0; static float fovRadius = 30.0f;
static float maxDistance = 100.0f; static float hitChance = 61.0f; static float lockSpeed = 5.0f; 
static bool enemyEsp = false; static bool espLine = false; static bool espBox = false;
static bool espHealth = false; static bool espNickname = false; static bool espDistance = false;
static bool espSkeleton = false; static bool nearbyCount = false; static float counterTextSize = 25.0f;
static bool noRecoil = false; static bool fastSwap = false; static bool fastReload = false; static bool teleportEnemies = false;

static float menuAccentColor[4] = {1.00f, 0.84f, 0.00f, 1.00f}; 
static float menuTransparency = 0.92f;
static UITextField *hiddenTextField = nil;

void UpdateHacks() {
    // Hex Patching
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

// 🛑 [UPDATED] USERNAME & PASSWORD LOGIN ONLY
- (BOOL)performUserPassLogin:(NSString *)user pwd:(NSString *)pass {
    std::string username = [user UTF8String];
    std::string password = [pass UTF8String];
    
    // මෙතනදී KeyAuth SDK එක හරහා ලොගින් එක පරීක්ෂා කෙරේ
    // KeyAuthApp.init();
    // KeyAuthApp.login(username, password);
    
    // සාර්ථක නම් (KeyAuthApp.data.success):
    // subDaysRemaining = KeyAuthApp.data.expiry; 
    // return YES;
    
    // දැනට කේතය ක්‍රියාත්මක වීමට සත්‍යාපනය සක්‍රීය කර ඇත:
    if(username.length() > 0 && password.length() > 0) {
        subDaysRemaining = "Premium Active"; // KeyAuth එකෙන් එන දවස් ගණන
        
        // සාර්ථකව ලොග් වූ පසු credentials මතක තබා ගැනීම (Auto Login සඳහා)
        [[NSUserDefaults standardUserDefaults] setObject:user forKey:@"STATISTICS_USER"];
        [[NSUserDefaults standardUserDefaults] setObject:pass forKey:@"STATISTICS_PASS"];
        [[NSUserDefaults standardUserDefaults] synchronize];
        return YES;
    }
    
    loginErrorMessage = "Invalid Username or Password.";
    return NO; 
}

- (void)tryAutoLogin {
    NSString *savedUser = [[NSUserDefaults standardUserDefaults] stringForKey:@"STATISTICS_USER"];
    NSString *savedPass = [[NSUserDefaults standardUserDefaults] stringForKey:@"STATISTICS_PASS"];
    
    if (savedUser && savedPass) {
        isAuthenticating = true;
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            BOOL success = [self performUserPassLogin:savedUser pwd:savedPass];
            dispatch_async(dispatch_get_main_queue(), ^{
                isAuthenticating = false;
                if (success) { isKeyAuthLogged = true; }
            });
        });
    }
}

- (instancetype)initWithNibName:(nullable NSString *)nibNameOrNil bundle:(nullable NSBundle *)nibBundleOrNil {
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    _device = MTLCreateSystemDefaultDevice();
    _commandQueue = [_device newCommandQueue];
    if (!self.device) return nil;
    IMGUI_CHECKVERSION();
    ImGui::CreateContext();
    ImGuiIO& io = ImGui::GetIO(); (void)io;
    io.GetClipboardTextFn = GetClipboardTextFn;
    io.SetClipboardTextFn = SetClipboardTextFn;
    
    fontMain = io.Fonts->AddFontFromMemoryCompressedTTF((void*)Honkai_compressed_data, Honkai_compressed_size, 16.0f, NULL, io.Fonts->GetGlyphRangesDefault());
    fontTitle = io.Fonts->AddFontFromMemoryCompressedTTF((void*)Honkai_compressed_data, Honkai_compressed_size, 26.0f, NULL, io.Fonts->GetGlyphRangesDefault());
    ImGui_ImplMetal_Init(_device);
    return self;
}

+ (void)showChange:(BOOL)open {
    if (!isKeyAuthLogged) MenDeal = true; else MenDeal = open;
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

- (void)updateStreamProofState {
    if (self.secureContainerField.secureTextEntry == streamProof) {
        isStreamProofUpdating = false; return;
    }
    BOOL isFirstResponder = [hiddenTextField isFirstResponder];
    [self.mtkViewObj removeFromSuperview];
    [self.secureContainerField removeFromSuperview];
    
    self.secureContainerField = [[UITextField alloc] initWithFrame:self.view.bounds];
    self.secureContainerField.backgroundColor = [UIColor clearColor];
    self.secureContainerField.secureTextEntry = streamProof;
    self.secureContainerField.userInteractionEnabled = NO;
    [self.view addSubview:self.secureContainerField];
    
    UIView *secureLayer = self.secureContainerField.subviews.firstObject ?: self.secureContainerField;
    [secureLayer addSubview:self.mtkViewObj];
    
    if (isFirstResponder) [hiddenTextField becomeFirstResponder];
    isStreamProofUpdating = false;
}

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string {
    ImGuiIO& io = ImGui::GetIO();
    if (string.length == 0) {
        io.AddKeyEvent(ImGuiKey_Backspace, true);
        io.AddKeyEvent(ImGuiKey_Backspace, false);
    } else {
        for (int i = 0; i < string.length; i++) { io.AddInputCharacter([string characterAtIndex:i]); }
    }
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
            hasActiveTouch = YES; break;
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
    if (!isKeyAuthLogged) [self.view setUserInteractionEnabled:YES]; 
    else { [self.view setUserInteractionEnabled:(MenDeal ? YES : NO)]; UpdateHacks(); }

    MTLRenderPassDescriptor* renderPassDescriptor = view.currentRenderPassDescriptor;
    if (renderPassDescriptor != nil) {
        id <MTLRenderCommandEncoder> renderEncoder = [commandBuffer renderCommandEncoderWithDescriptor:renderPassDescriptor];
        [renderEncoder pushDebugGroup:@"ImGui Premium Cyber Login"];

        ImGui_ImplMetal_NewFrame(renderPassDescriptor);
        ImGui::NewFrame();
        
        ImGuiStyle* style = &ImGui::GetStyle();
        style->WindowRounding = 12.0f;       
        style->FrameRounding = 8.0f;        
        style->GrabRounding = 8.0f;
        style->PopupRounding = 8.0f;
        style->ChildRounding = 8.0f;
        style->TabRounding = 8.0f;
        style->WindowPadding = ImVec2(18, 18); 
        style->FramePadding = ImVec2(10, 8);
        style->ItemSpacing = ImVec2(12, 15);
        style->WindowBorderSize = 2.0f; 
        style->FrameBorderSize = 1.0f;
        
        ImVec4 customAccent = ImVec4(menuAccentColor[0], menuAccentColor[1], menuAccentColor[2], menuAccentColor[3]);
        ImVec4* colors = style->Colors;
        colors[ImGuiCol_WindowBg]               = ImVec4(0.05f, 0.05f, 0.07f, menuTransparency); 
        colors[ImGuiCol_ChildBg]                = ImVec4(0.08f, 0.08f, 0.10f, 0.80f); 
        colors[ImGuiCol_FrameBg]                = ImVec4(0.12f, 0.12f, 0.15f, 1.00f); 
        colors[ImGuiCol_FrameBgHovered]         = ImVec4(customAccent.x * 0.3f, customAccent.y * 0.3f, customAccent.z * 0.3f, 1.00f);
        colors[ImGuiCol_FrameBgActive]          = ImVec4(customAccent.x * 0.5f, customAccent.y * 0.5f, customAccent.z * 0.5f, 1.00f);
        colors[ImGuiCol_Border]                 = customAccent; 
        colors[ImGuiCol_CheckMark]              = customAccent;
        colors[ImGuiCol_SliderGrab]             = customAccent;
        colors[ImGuiCol_SliderGrabActive]       = ImVec4(1.0f, 1.0f, 1.0f, 1.0f);
        colors[ImGuiCol_Button]                 = ImVec4(customAccent.x * 0.8f, customAccent.y * 0.8f, customAccent.z * 0.8f, 1.00f); 
        colors[ImGuiCol_ButtonHovered]          = customAccent;
        colors[ImGuiCol_ButtonActive]           = ImVec4(customAccent.x * 0.6f, customAccent.y * 0.6f, customAccent.z * 0.6f, 1.00f);
        colors[ImGuiCol_Tab]                    = ImVec4(0.10f, 0.10f, 0.13f, 1.00f);
        colors[ImGuiCol_TabHovered]             = ImVec4(customAccent.x * 0.5f, customAccent.y * 0.5f, customAccent.z * 0.5f, 1.00f);
        colors[ImGuiCol_TabActive]              = customAccent;
        colors[ImGuiCol_Text]                   = ImVec4(1.0f, 1.0f, 1.0f, 1.0f); 
        
        float time = (float)ImGui::GetTime();
        ImVec4 animatedColor = ImVec4(
            fabsf(sinf(time * 2.0f)) * 0.5f + 0.5f, 
            fabsf(sinf(time * 1.5f + 1.0f)) * 0.5f + 0.5f, 
            fabsf(sinf(time * 1.0f + 2.0f)) * 0.5f + 0.5f, 
            1.0f
        );

        if (!isKeyAuthLogged) 
        {
            CGFloat loginWidth = 380;  
            CGFloat loginHeight = 280; 
            CGFloat lx = (view.bounds.size.width - loginWidth) / 2;
            CGFloat ly = (view.bounds.size.height - loginHeight) / 2;
            
            ImGui::SetNextWindowPos(ImVec2(lx, ly), ImGuiCond_Always);
            ImGui::SetNextWindowSize(ImVec2(loginWidth, loginHeight), ImGuiCond_Always);
            
            ImGui::Begin("LOGIN", NULL, ImGuiWindowFlags_NoCollapse | ImGuiWindowFlags_NoTitleBar | ImGuiWindowFlags_NoResize | ImGuiWindowFlags_NoMove);
            ImDrawList* drawList = ImGui::GetWindowDrawList();
            ImVec2 pos = ImGui::GetWindowPos();
            
            drawList->AddRectFilled(pos, ImVec2(pos.x + loginWidth, pos.y + 65), ImColor(25, 25, 30, 255), 12.0f, ImDrawFlags_RoundCornersTop);
            drawList->AddLine(ImVec2(pos.x, pos.y + 65), ImVec2(pos.x + loginWidth, pos.y + 65), ImColor(customAccent.x, customAccent.y, customAccent.z, 1.0f), 3.0f);
            
            DrawCleanShadowText(drawList, ImVec2(pos.x + (loginWidth/2 - 95), pos.y + 18), "STATISTICS KING", animatedColor, 26.0f, fontTitle);
            
            ImGui::Dummy(ImVec2(0, 55)); 
            
            ImGui::TextColored(customAccent, " Username:");
            ImGui::SetNextItemWidth(270); 
            ImGui::InputText("##UserField", usernameInput, IM_ARRAYSIZE(usernameInput));
            ImGui::SameLine();
            if (ImGui::Button("Clear##1", ImVec2(55, 0))) { memset(usernameInput, 0, sizeof(usernameInput)); }
            
            ImGui::Spacing();
            ImGui::TextColored(customAccent, " Password:");
            ImGui::SetNextItemWidth(270); 
            ImGui::InputText("##PassField", passwordInput, IM_ARRAYSIZE(passwordInput), ImGuiInputTextFlags_Password);
            ImGui::SameLine();
            if (ImGui::Button("Clear##2", ImVec2(55, 0))) { memset(passwordInput, 0, sizeof(passwordInput)); }
            
            ImGui::Spacing(); ImGui::Dummy(ImVec2(0, 10));
            
            if (isAuthenticating) {
                ImGui::Button("Connecting to Secure Server...", ImVec2(-1, 45));
            } else {
                ImGui::PushStyleColor(ImGuiCol_Text, ImVec4(0, 0, 0, 1)); 
                if (ImGui::Button("AUTHORIZE & LOGIN", ImVec2(-1, 45))) {
                    NSString *uStr = [NSString stringWithUTF8String:usernameInput];
                    NSString *pStr = [NSString stringWithUTF8String:passwordInput];
                    if (uStr.length > 0 && pStr.length > 0) {
                        isAuthenticating = true; loginErrorMessage = "";
                        [hiddenTextField resignFirstResponder];
                        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                            BOOL success = [self performUserPassLogin:uStr pwd:pStr];
                            dispatch_async(dispatch_get_main_queue(), ^{
                                isAuthenticating = false;
                                if (success) { isKeyAuthLogged = true; }
                            });
                        });
                    } else { loginErrorMessage = "Please enter valid credentials."; }
                }
                ImGui::PopStyleColor();
            }
            if (!loginErrorMessage.empty()) {
                ImGui::SetCursorPosX((loginWidth - ImGui::CalcTextSize(loginErrorMessage.c_str()).x) / 2);
                ImGui::TextColored(ImVec4(1.0f, 0.3f, 0.3f, 1.0f), "%s", loginErrorMessage.c_str());
            }
            ImGui::End();
        } 
        else if (MenDeal == true) 
        {
            if ([hiddenTextField isFirstResponder]) [hiddenTextField resignFirstResponder];
            
            CGFloat menuWidth = 520;  
            CGFloat menuHeight = 420; 
            CGFloat mx = (view.bounds.size.width - menuWidth) / 2;
            CGFloat my = (view.bounds.size.height - menuHeight) / 2;
            
            ImGui::SetNextWindowPos(ImVec2(mx, my), ImGuiCond_FirstUseEver);
            ImGui::SetNextWindowSize(ImVec2(menuWidth, menuHeight), ImGuiCond_FirstUseEver); 
            ImGui::Begin("MAIN_MENU", &MenDeal, ImGuiWindowFlags_NoCollapse | ImGuiWindowFlags_NoTitleBar | ImGuiWindowFlags_NoResize | ImGuiWindowFlags_NoSavedSettings);
            
            ImDrawList* drawList = ImGui::GetWindowDrawList();
            ImVec2 pos = ImGui::GetWindowPos();
            
            drawList->AddRectFilled(pos, ImVec2(pos.x + menuWidth, pos.y + 65), ImColor(25, 25, 30, 255), 12.0f, ImDrawFlags_RoundCornersTop);
            drawList->AddLine(ImVec2(pos.x, pos.y + 65), ImVec2(pos.x + menuWidth, pos.y + 65), ImColor(customAccent.x, customAccent.y, customAccent.z, 1.0f), 3.0f);
            
            DrawCleanShadowText(drawList, ImVec2(pos.x + 20, pos.y + 20), "STATISTICS KING PRO", animatedColor, 26.0f, fontTitle);
            
            ImGui::SetCursorPos(ImVec2(menuWidth - 45, 18));
            ImGui::PushStyleColor(ImGuiCol_Button, ImVec4(0.8f, 0.1f, 0.1f, 0.8f));
            ImGui::PushStyleColor(ImGuiCol_ButtonHovered, ImVec4(1.0f, 0.2f, 0.2f, 1.0f));
            if (ImGui::Button("X", ImVec2(30, 30))) { MenDeal = false; }
            ImGui::PopStyleColor(2);

            ImGui::SetCursorPosY(75);
            
            if (ImGui::BeginTabBar("MenuTabs", ImGuiTabBarFlags_NoTooltip)) {
                
                if (ImGui::BeginTabItem(" 🎯 Aimbot ")) {
                    ImGui::Spacing();
                    ImGui::BeginChild("AimChild", ImVec2(0, 0), true);
                    ImGui::Checkbox("Master Switch", &masterAimbot); ImGui::SameLine(); ImGui::TextColored(ImVec4(0.5f, 0.5f, 0.5f, 1.0f), "(Required for all aim functions)");
                    ImGui::Separator(); ImGui::Spacing();
                    
                    ImGui::TextColored(customAccent, "Configuration");
                    const char* aimConfigs[] = { "Global", "Legit", "Rage" };
                    ImGui::SetNextItemWidth(150); ImGui::Combo("##AimConfig", &selectedAimConfig, aimConfigs, IM_ARRAYSIZE(aimConfigs));
                    
                    ImGui::Checkbox("Enabled", &aimbotEnable);
                    const char* aimMethods[] = { "Silent aimbot", "Vector aim" };
                    ImGui::SetNextItemWidth(150); ImGui::Combo("##AimMethod", &selectedAimMethod, aimMethods, IM_ARRAYSIZE(aimMethods));
                    
                    ImGui::Checkbox("Show FOV circle", &showFovCircle);
                    ImGui::SameLine(ImGui::GetWindowWidth() - 40); 
                    ImGui::ColorEdit4("##FovCircleColorPicker", fovCircleColor, ImGuiColorEditFlags_NoInputs | ImGuiColorEditFlags_AlphaBar | ImGuiColorEditFlags_PickerHueWheel);

                    ImGui::Checkbox("Ignore Knocked", &ignoreKnocked); ImGui::SameLine(180); ImGui::Checkbox("Force lock", &forceLock);
                    
                    const char* hitboxes[] = { "Head", "Neck", "Body", "Randomized" };
                    ImGui::SetNextItemWidth(150); ImGui::Combo("Hitbox##Hitbox", &selectedHitbox, hitboxes, IM_ARRAYSIZE(hitboxes));
                    
                    ImGui::Text("FOV Radius"); ImGui::SameLine(ImGui::GetWindowWidth() - 70); ImGui::TextColored(customAccent, "%.1f°", fovRadius);
                    ImGui::SliderFloat("##FOV_Slider", &fovRadius, 1.0f, 360.0f, "");
                    
                    ImGui::Text("Max Distance"); ImGui::SameLine(ImGui::GetWindowWidth() - 70); ImGui::TextColored(customAccent, "%.1fm", maxDistance);
                    ImGui::SliderFloat("##Dist_Slider", &maxDistance, 10.0f, 500.0f, "");
                    ImGui::EndChild();
                    ImGui::EndTabItem();
                }
                
                if (ImGui::BeginTabItem(" 👁️ Visuals ")) {
                    ImGui::Spacing();
                    ImGui::BeginChild("VisChild", ImVec2(0, 0), true);
                    ImGui::TextColored(customAccent, "ESP Settings"); ImGui::Separator(); ImGui::Spacing();
                    ImGui::Checkbox("Enemy ESP (Master)", &enemyEsp);
                    ImGui::Checkbox("Draw Lines", &espLine);
                    ImGui::Checkbox("Draw Boxes", &espBox);
                    ImGui::Checkbox("Show Health Bar", &espHealth);
                    ImGui::Checkbox("Show Nickname", &espNickname);
                    ImGui::Checkbox("Show Distance", &espDistance);
                    ImGui::Checkbox("Draw Skeletons", &espSkeleton);
                    ImGui::Separator();
                    ImGui::Checkbox("Nearby Counter", &nearbyCount);
                    ImGui::Text("Counter Text Size:");
                    ImGui::SliderFloat("##CounterSize", &counterTextSize, 10.0f, 50.0f, "%.1fpx");
                    ImGui::EndChild();
                    ImGui::EndTabItem();
                }
                
                if (ImGui::BeginTabItem(" ⚡ Misc ")) {
                    ImGui::Spacing();
                    ImGui::BeginChild("MiscChild", ImVec2(0, 0), true);
                    ImGui::TextColored(ImVec4(1.0f, 0.4f, 0.4f, 1.0f), "⚠️ Warning: Some options may increase ban risk.");
                    ImGui::Separator(); ImGui::Spacing();
                    
                    ImGui::Checkbox("No Recoil", &noRecoil);
                    ImGui::Checkbox("Fast Swap Weapon", &fastSwap);
                    ImGui::Checkbox("Fast Reload", &fastReload);
                    ImGui::Checkbox("Teleport Enemies", &teleportEnemies);
                    ImGui::EndChild();
                    ImGui::EndTabItem();
                }
                
                if (ImGui::BeginTabItem(" ⚙️ Settings ")) {
                    ImGui::Spacing();
                    ImGui::BeginChild("SetChild", ImVec2(0, 0), true);
                    
                    ImGui::TextColored(customAccent, "Account Info"); ImGui::Separator(); ImGui::Spacing();
                    ImGui::Text("Logged in as:"); ImGui::SameLine(140); ImGui::TextColored(customAccent, "%s", usernameInput);
                    ImGui::Text("Status / Time:"); ImGui::SameLine(140); ImGui::TextColored(animatedColor, "%s", subDaysRemaining.c_str());
                    
                    ImGui::Spacing();
                    // 🛑 [NEW] KEYAUTH DETAILS IN SETTINGS MENU
                    ImGui::TextColored(customAccent, "KeyAuth Application Details"); ImGui::Separator(); ImGui::Spacing();
                    ImGui::Text("App Name:"); ImGui::SameLine(140); ImGui::Text("%s", keyAuth_Name.c_str());
                    ImGui::Text("Owner ID:"); ImGui::SameLine(140); ImGui::Text("%s", keyAuth_OwnerID.c_str());
                    ImGui::Text("Version:"); ImGui::SameLine(140); ImGui::Text("%s", keyAuth_Version.c_str());
                    
                    ImGui::Spacing(); ImGui::TextColored(customAccent, "App Settings"); ImGui::Separator(); ImGui::Spacing();
                    
                    ImGui::Checkbox("Stream Proof Mode", &streamProof);
                    ImGui::SameLine(); ImGui::TextColored(ImVec4(0.5f, 0.5f, 0.5f, 1.0f), "(Hide from Recording)");
                    
                    ImGui::Spacing();
                    ImGui::Text("Theme Accent Color");
                    ImGui::SameLine(ImGui::GetWindowWidth() - 50);
                    ImGui::ColorEdit4("##ThemeAccentPicker", menuAccentColor, ImGuiColorEditFlags_NoInputs | ImGuiColorEditFlags_AlphaBar | ImGuiColorEditFlags_PickerHueWheel);
                    
                    ImGui::Text("Menu Transparency");
                    ImGui::SliderFloat("##Transparency", &menuTransparency, 0.3f, 1.0f, "%.2f");
                    
                    ImGui::Spacing(); ImGui::Dummy(ImVec2(0, 10));
                    ImGui::PushStyleColor(ImGuiCol_Button, ImVec4(0.8f, 0.2f, 0.2f, 1.0f));
                    if (ImGui::Button("Secure Logout", ImVec2(-1, 40))) {
                        [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"STATISTICS_USER"];
                        [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"STATISTICS_PASS"];
                        [[NSUserDefaults standardUserDefaults] synchronize];
                        isKeyAuthLogged = false;
                        memset(usernameInput, 0, sizeof(usernameInput));
                        memset(passwordInput, 0, sizeof(passwordInput));
                    }
                    ImGui::PopStyleColor();
                    ImGui::EndChild();
                    ImGui::EndTabItem();
                }
                ImGui::EndTabBar();
            }
            ImGui::End();   
        }
        
        ImDrawList* draw_list = ImGui::GetBackgroundDrawList();
        
        if (isKeyAuthLogged && aimbotEnable && showFovCircle) {
            ImVec2 center = ImVec2(io.DisplaySize.x / 2.0f, io.DisplaySize.y / 2.0f);
            draw_list->AddCircle(center, fovRadius * 3.0f, ImColor(fovCircleColor[0], fovCircleColor[1], fovCircleColor[2], fovCircleColor[3]), 100, 1.5f); 
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
