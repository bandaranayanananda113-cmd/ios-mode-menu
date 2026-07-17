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
// GAME OFFSETS PLACEHOLDERS
// ==========================================
#define OFFSET_NO_RECOIL       0x0000000 
#define OFFSET_FAST_SWAP       0x0000000 
#define OFFSET_FAST_RELOAD     0x0000000 
#define OFFSET_TELEPORT        0x0000000 
#define OFFSET_AIMBOT_LOCK     0x0000000 
#define OFFSET_CAMERA_FOV      0x0000000
#define OFFSET_ESP_BONE        0x0000000

// ==========================================
// SAFE MEMORY PATCHING FUNCTIONS (Errors Fixed)
// ==========================================
void safePatchMemory(uintptr_t address, const uint8_t* bytes, size_t size) {
    if (address == 0) return;
    
    // PROT_COPY ඉවත් කර නිවැරදි කර ඇත
    vm_protect(mach_task_self(), (vm_address_t)address, size, FALSE, PROT_READ | PROT_WRITE);
    memcpy((void*)address, bytes, size);
    vm_protect(mach_task_self(), (vm_address_t)address, size, FALSE, PROT_READ | PROT_EXEC);
}

uintptr_t get_GameModule_Base(const char* moduleName) {
    uint32_t count = _dyld_image_count();
    for (uint32_t i = 0; i < count; i++) {
        const char* name = _dyld_get_image_name(i);
        if (name && strstr(name, moduleName)) {
            // Type Cast error එක නිවැරදි කර ඇත
            return (uintptr_t)_dyld_get_image_header(i);
        }
    }
    return 0;
}

// .h file එකත් එක්ක ගැටෙන්නේ නැති වෙන්න නම getLocalRealOffset ලෙස වෙනස් කර ඇත
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
// PROFESSIONAL CHEAT VARIABLES
// ==========================================
static bool streamProof = true; // <-- Default ON (Menu එක දාද්දිම ON)
static bool masterAimbot = false;
static bool aimbotEnable = false;
static int selectedAimConfig = 0; 
static int selectedAimMethod = 0; 
static bool showFovCircle = false;
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
// HACK LOGIC FUNCTION
// ==========================================
void UpdateHacks() {
    if (!isKeyAuthLogged) return; 

    // Aimbot Logic
    if (masterAimbot && aimbotEnable) {
        if (selectedAimMethod == 0) {
            // Silent Aim Patch 
        } else {
            // Vector Aim Patch
        }
    } else {
        // Restore Aimbot
    }

    if (enemyEsp) {
        if (espLine) { /* Line ESP Hook */ }
        if (espBox)  { /* Box ESP Hook */ }
    }

    // No Recoil Memory Patching Logic (දැන් Error නැතිව වැඩ කරයි)
    static bool lastNoRecoil = false;
    if (noRecoil != lastNoRecoil) {
        uintptr_t addr = getLocalRealOffset(OFFSET_NO_RECOIL);
        if (noRecoil) {
            const uint8_t patch[] = { 0x1F, 0x20, 0x03, 0xD5 }; // Placeholder Hex 
            safePatchMemory(addr, patch, sizeof(patch));
        } else {
            const uint8_t restore[] = { 0xFF, 0x43, 0x00, 0xD1 }; // Placeholder Hex
            safePatchMemory(addr, restore, sizeof(restore));
        }
        lastNoRecoil = noRecoil;
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
@property (nonatomic, strong) UITextField *secureContainerField; // Stream Proof Container
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
        if (data) {
            initJson = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        }
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
        if (data) {
            loginJson = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        }
        dispatch_semaphore_signal(sema2);
    }] resume];
    
    dispatch_semaphore_wait(sema2, dispatch_time(DISPATCH_TIME_NOW, 8 * NSEC_PER_SEC));
    
    if (loginJson && [loginJson[@"success"] boolValue]) {
        NSDictionary *info = loginJson[@"info"];
        if (info) {
            id expiryVal = info[@"expiry"];
            if (expiryVal) {
                subExpiryDate = [NSString stringWithFormat:@"%@", expiryVal].UTF8String;
            }
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
                if (success) {
                    isKeyAuthLogged = true;
                } else {
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

    if (!self.device) abort();
    IMGUI_CHECKVERSION();
    ImGui::CreateContext();
    ImGuiIO& io = ImGui::GetIO(); (void)io;
    
    io.GetClipboardTextFn = GetClipboardTextFn;
    io.SetClipboardTextFn = SetClipboardTextFn;
    
    ImFont* font = io.Fonts->AddFontFromMemoryCompressedTTF((void*)Honkai_compressed_data, Honkai_compressed_size, 45.0f, NULL, io.Fonts->GetGlyphRangesDefault());
    ImGui_ImplMetal_Init(_device);
    
    return self;
}

+ (void)showChange:(BOOL)open
{
    if (!isKeyAuthLogged) {
        MenDeal = true;
    } else {
        MenDeal = open;
    }
}

- (void)loadView
{
    CGFloat w = [UIApplication sharedApplication].windows[0].rootViewController.view.frame.size.width;
    CGFloat h = [UIApplication sharedApplication].windows[0].rootViewController.view.frame.size.height;
    
    // Main Root View
    self.view = [[UIView alloc] initWithFrame:CGRectMake(0, 0, w, h)];
    self.view.backgroundColor = [UIColor clearColor];
    
    // Stream Proof Container (Secure Text Field)
    self.secureContainerField = [[UITextField alloc] initWithFrame:self.view.bounds];
    self.secureContainerField.backgroundColor = [UIColor clearColor];
    self.secureContainerField.secureTextEntry = streamProof; // Stream proof setting
    self.secureContainerField.userInteractionEnabled = YES;
    [self.view addSubview:self.secureContainerField];
    
    // Get inner secure layer to place MTKView
    UIView *secureLayer = self.secureContainerField.subviews.firstObject;
    if (!secureLayer) secureLayer = self.secureContainerField;
    secureLayer.userInteractionEnabled = YES;
    
    // Metal View for ImGui
    self.mtkViewObj = [[MTKView alloc] initWithFrame:self.view.bounds];
    self.mtkViewObj.clearColor = MTLClearColorMake(0, 0, 0, 0);
    self.mtkViewObj.backgroundColor = [UIColor clearColor];
    self.mtkViewObj.clipsToBounds = YES;
    
    [secureLayer addSubview:self.mtkViewObj]; // Insert Metal view inside Secure Field
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

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string {
    ImGuiIO& io = ImGui::GetIO();
    for (int i = 0; i < string.length; i++) {
        io.AddInputCharacter([string characterAtIndex:i]);
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

- (void)updateIOWithTouchEvent:(UIEvent *)event
{
    UITouch *anyTouch = event.allTouches.anyObject;
    CGPoint touchLocation = [anyTouch locationInView:self.view];
    ImGuiIO &io = ImGui::GetIO();
    io.MousePos = ImVec2(touchLocation.x, touchLocation.y);

    BOOL hasActiveTouch = NO;
    for (UITouch *touch in event.allTouches)
    {
        if (touch.phase != UITouchPhaseEnded && touch.phase != UITouchPhaseCancelled)
        {
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

- (void)drawInMTKView:(MTKView*)view
{
    ImGuiIO& io = ImGui::GetIO();
    io.DisplaySize.x = view.bounds.size.width;
    io.DisplaySize.y = view.bounds.size.height;

    CGFloat framebufferScale = view.window.screen.scale ?: UIScreen.mainScreen.scale;
    io.DisplayFramebufferScale = ImVec2(framebufferScale, framebufferScale);
    io.DeltaTime = 1 / float(view.preferredFramesPerSecond ?: 120);
    
    static bool wasWantTextInput = false;
    if (io.WantTextInput && !wasWantTextInput) {
        [hiddenTextField becomeFirstResponder];
    } else if (!io.WantTextInput && wasWantTextInput) {
        [hiddenTextField resignFirstResponder];
        hiddenTextField.text = @""; 
    }
    wasWantTextInput = io.WantTextInput;
    
    // Update iOS Secure Container State (Stream Proof Enable/Disable dynamically)
    self.secureContainerField.secureTextEntry = streamProof;

    id<MTLCommandBuffer> commandBuffer = [self.commandQueue commandBuffer];
    
    if (!isKeyAuthLogged) {
        [self.view setUserInteractionEnabled:YES];
    } else {
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
        
        ImGuiStyle* style = &ImGui::GetStyle();
        style->WindowRounding = 12.0f;       
        style->FrameRounding = 6.0f;        
        style->GrabRounding = 10.0f;
        style->PopupRounding = 6.0f;
        style->ChildRounding = 8.0f;
        style->WindowPadding = ImVec2(14, 14); 
        style->FramePadding = ImVec2(10, 8);
        style->ItemSpacing = ImVec2(10, 10);
        style->WindowBorderSize = 1.0f; 
        style->FrameBorderSize = 1.0f;

        ImVec4* colors = style->Colors;
        colors[ImGuiCol_WindowBg]               = ImVec4(0.06f, 0.07f, 0.10f, menuTransparency); 
        colors[ImGuiCol_ChildBg]                = ImVec4(0.09f, 0.10f, 0.14f, 0.60f); 
        colors[ImGuiCol_FrameBg]                = ImVec4(0.11f, 0.13f, 0.18f, 1.00f); 
        colors[ImGuiCol_FrameBgHovered]         = ImVec4(0.15f, 0.18f, 0.24f, 1.00f);
        colors[ImGuiCol_FrameBgActive]          = ImVec4(0.18f, 0.22f, 0.30f, 1.00f);
        
        ImVec4 customAccent = ImVec4(menuAccentColor[0], menuAccentColor[1], menuAccentColor[2], menuAccentColor[3]);
        colors[ImGuiCol_Border]                 = ImVec4(customAccent.x, customAccent.y, customAccent.z, 0.40f); 
        colors[ImGuiCol_CheckMark]              = customAccent;
        colors[ImGuiCol_SliderGrab]             = customAccent;
        colors[ImGuiCol_SliderGrabActive]       = ImVec4(customAccent.x + 0.1f, customAccent.y + 0.1f, customAccent.z + 0.1f, 1.0f);
        colors[ImGuiCol_Button]                 = ImVec4(customAccent.x, customAccent.y, customAccent.z, 0.15f); 
        colors[ImGuiCol_ButtonHovered]          = ImVec4(customAccent.x, customAccent.y, customAccent.z, 0.35f);
        colors[ImGuiCol_ButtonActive]           = ImVec4(customAccent.x, customAccent.y, customAccent.z, 0.60f);
        colors[ImGuiCol_Text]                   = ImVec4(0.92f, 0.94f, 0.98f, 1.00f); 
        colors[ImGuiCol_TextDisabled]           = ImVec4(0.55f, 0.58f, 0.65f, 1.00f); 
        
        ImFont* font = ImGui::GetFont();
        font->Scale = 14.f / font->FontSize;
        
        // ==========================================
        // SCREEN 1: LOGIN
        // ==========================================
        if (!isKeyAuthLogged) 
        {
            CGFloat loginWidth = 360;  
            CGFloat loginHeight = 280; 
            CGFloat lx = (view.bounds.size.width - loginWidth) / 2;
            CGFloat ly = (view.bounds.size.height - loginHeight) / 2;
            
            ImGui::SetNextWindowPos(ImVec2(lx, ly), ImGuiCond_Always);
            ImGui::SetNextWindowSize(ImVec2(loginWidth, loginHeight), ImGuiCond_Always);
            
            ImGuiWindowFlags login_flags = ImGuiWindowFlags_NoCollapse | ImGuiWindowFlags_NoTitleBar | ImGuiWindowFlags_NoResize | ImGuiWindowFlags_NoSavedSettings | ImGuiWindowFlags_NoMove;
            
            ImGui::Begin("LOGIN_SYSTEM", NULL, login_flags);
            
            ImDrawList* drawList = ImGui::GetWindowDrawList();
            ImVec2 pos = ImGui::GetWindowPos();
            
            drawList->AddRectFilled(pos, ImVec2(pos.x + loginWidth, pos.y + 65), ImColor(15, 18, 25, 255), 12.0f, ImDrawCornerFlags_All);
            drawList->AddLine(ImVec2(pos.x, pos.y + 65), ImVec2(pos.x + loginWidth, pos.y + 65), ImColor(customAccent.x, customAccent.y, customAccent.z, 0.8f), 2.0f);
            
            ImGui::SetCursorPos(ImVec2(20, 18));
            ImVec2 textPos = ImGui::GetCursorScreenPos();
            Draw3DAnimatedText(drawList, font, 24.0f, textPos, "STATISTICS KING", customAccent, false);
            ImGui::Dummy(ImVec2(0, 30)); 
            
            ImGui::SetCursorPos(ImVec2(20, 48));
            ImGui::TextDisabled("PREMIUM ACCESS");
            
            ImGui::SetCursorPosY(85);
            
            ImGui::TextDisabled("Username:");
            ImGui::SetNextItemWidth(260); 
            ImGui::InputText("##UserField", usernameInput, IM_ARRAYSIZE(usernameInput));
            ImGui::SameLine();
            if (ImGui::Button("Clear##1", ImVec2(55, 0))) {
                memset(usernameInput, 0, sizeof(usernameInput));
            }
            
            ImGui::Spacing();
            
            ImGui::TextDisabled("Password:");
            ImGui::SetNextItemWidth(260); 
            ImGui::InputText("##PassField", passwordInput, IM_ARRAYSIZE(passwordInput), ImGuiInputTextFlags_Password);
            ImGui::SameLine();
            if (ImGui::Button("Clear##2", ImVec2(55, 0))) {
                memset(passwordInput, 0, sizeof(passwordInput));
            }
            
            ImGui::Spacing();
            ImGui::Separator();
            ImGui::Spacing();
            
            if (isAuthenticating) {
                ImGui::Button("Authenticating Please Wait...", ImVec2(-1, 42));
            } else {
                if (ImGui::Button("Login to System", ImVec2(-1, 42))) {
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
                                if (success) {
                                    isKeyAuthLogged = true;
                                }
                            });
                        });
                    } else {
                        loginErrorMessage = "Username and Password cannot be empty.";
                    }
                }
            }
            
            if (!loginErrorMessage.empty()) {
                ImGui::Spacing();
                ImGui::TextColored(ImVec4(1.0f, 0.3f, 0.3f, 1.0f), "[Error] %s", loginErrorMessage.c_str());
            }
            
            ImGui::End();
        } 
        
        // ==========================================
        // SCREEN 2: MAIN MENU
        // ==========================================
        else if (MenDeal == true) 
        {
            if ([hiddenTextField isFirstResponder]) {
                [hiddenTextField resignFirstResponder];
            }

            CGFloat menuWidth = 540;  
            CGFloat menuHeight = 350; 
            CGFloat mx = (view.bounds.size.width - menuWidth) / 2;
            CGFloat my = (view.bounds.size.height - menuHeight) / 2;
            
            ImGui::SetNextWindowPos(ImVec2(mx, my), ImGuiCond_FirstUseEver);
            ImGui::SetNextWindowSize(ImVec2(menuWidth, menuHeight), ImGuiCond_FirstUseEver); 
            
            ImGuiWindowFlags window_flags = ImGuiWindowFlags_NoCollapse | ImGuiWindowFlags_NoTitleBar | ImGuiWindowFlags_NoResize | ImGuiWindowFlags_NoSavedSettings;
            ImGui::Begin("STATISTICS_MAIN_CONTAINER", &MenDeal, window_flags);
            
            ImDrawList* internalDrawList = ImGui::GetWindowDrawList();
            ImVec2 windowPos = ImGui::GetWindowPos();
            ImVec2 windowSize = ImGui::GetWindowSize();
            
            std::string watermarkText = "STATISTICS KING";
            font->Scale = 45.f / font->FontSize; 
            ImVec2 textSize = ImGui::CalcTextSize(watermarkText.c_str());
            font->Scale = 14.f / font->FontSize; 
            
            ImVec2 wmPos = ImVec2(
                windowPos.x + 140.0f + ((windowSize.x - 140.0f) - textSize.x) * 0.5f,
                windowPos.y + (windowSize.y - textSize.y) * 0.5f
            );
            
            Draw3DAnimatedText(internalDrawList, font, 45.0f, wmPos, watermarkText.c_str(), customAccent, true);

            ImGui::Columns(2, "MainLayout", false);
            ImGui::SetColumnWidth(0, 140.0f); 
            
            ImGui::PushStyleColor(ImGuiCol_ChildBg, ImVec4(0.05f, 0.06f, 0.09f, 0.90f)); 
            ImGui::BeginChild("Sidebar", ImVec2(0, 0), true);
            
            ImGui::Spacing();
            
            ImGui::SetCursorPosX(10);
            ImVec2 sidebarTextPos = ImGui::GetCursorScreenPos();
            Draw3DAnimatedText(internalDrawList, font, 14.0f, sidebarTextPos, "STATISTICS KING", customAccent, false);
            ImGui::Dummy(ImVec2(0, 20)); 

            ImGui::Separator();
            ImGui::Spacing();

            static int activeTab = 0; 
            const char* tabs[] = { " Aimbot", " Visuals", " Misc", " Settings" };
            
            for (int i = 0; i < 4; i++) {
                bool is_selected = (activeTab == i);
                if (is_selected) {
                    ImGui::PushStyleColor(ImGuiCol_Button, ImVec4(customAccent.x, customAccent.y, customAccent.z, 0.20f));
                    ImGui::PushStyleColor(ImGuiCol_ButtonHovered, ImVec4(customAccent.x, customAccent.y, customAccent.z, 0.30f));
                    ImGui::PushStyleColor(ImGuiCol_ButtonActive, ImVec4(customAccent.x, customAccent.y, customAccent.z, 0.50f));
                    ImGui::PushStyleColor(ImGuiCol_Text, customAccent);
                } else {
                    ImGui::PushStyleColor(ImGuiCol_Button, ImVec4(0, 0, 0, 0));
                    ImGui::PushStyleColor(ImGuiCol_ButtonHovered, ImVec4(1, 1, 1, 0.03f));
                    ImGui::PushStyleColor(ImGuiCol_ButtonActive, ImVec4(1, 1, 1, 0.06f));
                    ImGui::PushStyleColor(ImGuiCol_Text, ImVec4(0.70f, 0.73f, 0.80f, 1.00f));
                }

                ImGui::SetCursorPosX(8);
                if (ImGui::Button(tabs[i], ImVec2(120, 38))) {
                    activeTab = i;
                }
                ImGui::PopStyleColor(4);
                ImGui::Spacing();
            }
            ImGui::EndChild();
            ImGui::PopStyleColor(); 

            ImGui::NextColumn();
            
            ImGui::BeginChild("ContentArea", ImVec2(0, 0), false);
            
            ImGui::Spacing();
            if (activeTab == 0) {
                ImGui::TextColored(customAccent, "AIMBOT CONFIGURATION");
            } else if (activeTab == 1) {
                ImGui::TextColored(customAccent, "VISUALS & ESP");
            } else if (activeTab == 2) {
                ImGui::TextColored(customAccent, "MISC MODIFICATIONS");
            } else {
                ImGui::TextColored(customAccent, "SYSTEM SETTINGS");
            }
            
            ImGui::SameLine(ImGui::GetWindowWidth() - 35);
            if (ImGui::Button("X", ImVec2(24, 24))) {
                MenDeal = false;
            }
            ImGui::Separator();
            ImGui::Spacing();

            // TAB 1: AIMBOT
            if (activeTab == 0) { 
                ImGui::Checkbox("Master Switch", &masterAimbot);
                
                ImGui::Text("Aimbot config");
                const char* aimConfigs[] = { "Global", "Legit", "Rage" };
                ImGui::SetNextItemWidth(-1);
                ImGui::Combo("##AimConfig", &selectedAimConfig, aimConfigs, IM_ARRAYSIZE(aimConfigs));
                
                ImGui::Checkbox("Enabled", &aimbotEnable);
                
                ImGui::Text("Aiming method");
                const char* aimMethods[] = { "Silent aimbot", "Vector aim" };
                ImGui::SetNextItemWidth(-1);
                ImGui::Combo("##AimMethod", &selectedAimMethod, aimMethods, IM_ARRAYSIZE(aimMethods));
                
                ImGui::Checkbox("Show FOV circle", &showFovCircle);
                ImGui::Checkbox("Ignore Knocked", &ignoreKnocked);
                ImGui::Checkbox("Force lock", &forceLock);
                
                ImGui::Spacing();
                ImGui::Text("Hitbox Target");
                const char* hitboxes[] = { "Head", "Neck", "Body", "Randomized" };
                ImGui::SetNextItemWidth(-1);
                ImGui::Combo("##Hitbox", &selectedHitbox, hitboxes, IM_ARRAYSIZE(hitboxes));
                
                ImGui::Spacing();
                ImGui::Text("FOV"); ImGui::SameLine(); ImGui::TextColored(customAccent, "%.1f°", fovRadius);
                ImGui::SetNextItemWidth(-1);
                ImGui::SliderFloat("##FOV_Slider", &fovRadius, 1.0f, 360.0f, "");
                
                ImGui::Spacing();
                ImGui::Text("Max distance"); ImGui::SameLine(); ImGui::TextColored(customAccent, "%.1fm", maxDistance);
                ImGui::SetNextItemWidth(-1);
                ImGui::SliderFloat("##Dist_Slider", &maxDistance, 10.0f, 500.0f, "");
                
                ImGui::Spacing();
                if (selectedAimMethod == 0) {
                    ImGui::Text("Hit chance"); ImGui::SameLine(); ImGui::TextColored(customAccent, "%.0f%%", hitChance);
                    ImGui::SetNextItemWidth(-1);
                    ImGui::SliderFloat("##Hit_Slider", &hitChance, 1.0f, 100.0f, "");
                } else if (selectedAimMethod == 1) {
                    ImGui::Text("Lock speed"); ImGui::SameLine(); ImGui::TextColored(customAccent, "%.1f", lockSpeed);
                    ImGui::SetNextItemWidth(-1);
                    ImGui::SliderFloat("##Lock_Slider", &lockSpeed, 1.0f, 20.0f, "");
                }
            } 
            
            // TAB 2: VISUALS
            else if (activeTab == 1) { 
                ImGui::Checkbox("Enemy ESP", &enemyEsp);
                ImGui::Checkbox("Line", &espLine);
                ImGui::Checkbox("Box", &espBox);
                ImGui::Checkbox("Health", &espHealth);
                ImGui::Checkbox("Nickname", &espNickname);
                ImGui::Checkbox("Distance", &espDistance);
                ImGui::Checkbox("Skeleton", &espSkeleton);
                ImGui::Checkbox("Nearby enemies count", &nearbyCount);
                
                ImGui::Spacing();
                ImGui::Text("Counter text size:"); ImGui::SameLine(); ImGui::TextColored(customAccent, "%.1fpx", counterTextSize);
                ImGui::SetNextItemWidth(-1);
                ImGui::SliderFloat("##CounterSize", &counterTextSize, 10.0f, 50.0f, "");
            } 
            
            // TAB 3: MISC
            else if (activeTab == 2) { 
                ImGui::PushStyleColor(ImGuiCol_Text, ImVec4(1.0f, 0.2f, 0.2f, 1.0f));
                ImGui::TextWrapped("Some options in this section may not be entirely safe. Use with caution.");
                ImGui::PopStyleColor();
                ImGui::Spacing();
                
                ImGui::Checkbox("No Recoil", &noRecoil);
                ImGui::Checkbox("Fast Swap Weapon", &fastSwap);
                ImGui::Checkbox("Fast Reload", &fastReload);
                ImGui::Checkbox("Teleport enemies to you", &teleportEnemies);
            } 
            
            // TAB 4: SETTINGS 
            else if (activeTab == 3) { 
                ImGui::TextColored(customAccent, "SYSTEM & THEME SETTINGS");
                ImGui::Separator();
                ImGui::Spacing();
                
                ImGui::Text("Logged User: %s", usernameInput);
                ImGui::Text("API Server: CONNECTED");
                ImGui::Text("Subscription: %s", subDaysRemaining.c_str());
                
                ImGui::Spacing();
                ImGui::Separator();
                ImGui::Spacing();

                // STREAM PROOF TOGGLE
                ImGui::Checkbox("Stream Proof (Hide from Record/Share)", &streamProof);
                ImGui::Spacing();
                
                ImGui::Text("Menu Accent Color balance:");
                ImGui::ColorEdit4("##ThemeAccentPicker", menuAccentColor, 
                                  ImGuiColorEditFlags_PickerHueWheel | 
                                  ImGuiColorEditFlags_AlphaBar | 
                                  ImGuiColorEditFlags_NoInputs | 
                                  ImGuiColorEditFlags_NoLabel);
                
                ImGui::Spacing();
                ImGui::Text("Menu Transparency:");
                ImGui::SetNextItemWidth(-1);
                ImGui::SliderFloat("##Transparency", &menuTransparency, 0.3f, 1.0f, "%.2f");
                
                ImGui::Spacing();
                if (ImGui::Button("Logout Account", ImVec2(-1, 38))) {
                    [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"STATISTICS_USER"];
                    [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"STATISTICS_PASS"];
                    [[NSUserDefaults standardUserDefaults] synchronize];
                    isKeyAuthLogged = false;
                    memset(usernameInput, 0, sizeof(usernameInput));
                    memset(passwordInput, 0, sizeof(passwordInput));
                }
            }
            
            ImGui::EndChild();
            ImGui::Columns(1); 
            ImGui::End();   
        }
        
        ImDrawList* draw_list = ImGui::GetBackgroundDrawList();
        
        if (isKeyAuthLogged && aimbotEnable && showFovCircle) {
            ImVec2 center = ImVec2(io.DisplaySize.x / 2.0f, io.DisplaySize.y / 2.0f);
            draw_list->AddCircle(center, fovRadius * 3.0f, ImColor(customAccent.x, customAccent.y, customAccent.z, 0.8f), 100, 1.2f);
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
