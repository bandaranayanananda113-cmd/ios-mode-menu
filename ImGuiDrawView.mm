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
#import "5Toubun/dobby.h" // Dobby Code Patching සඳහා

// ==========================================
// GAME OFFSETS - මෙතනට ඔයාගේ Offsets දාන්න
// ==========================================
#define OFFSET_NO_RECOIL       0x0000000 
#define OFFSET_FAST_SWAP       0x0000000 
#define OFFSET_FAST_RELOAD     0x0000000 
#define OFFSET_TELEPORT        0x0000000 
#define OFFSET_AIMBOT_LOCK     0x0000000 
#define OFFSET_CAMERA_FOV      0x0000000
#define OFFSET_ESP_BONE        0x0000000

// ==========================================
// SAFE MEMORY PATCHING FUNCTIONS
// ==========================================
void safePatchMemory(uintptr_t address, const uint8_t* bytes, size_t size) {
    if (address == 0) return;
    
    // iOS Memory Protection එක Bypass කිරීම (PROT_COPY ඉවත් කර නිවැරදි කර ඇත)
    vm_protect(mach_task_self(), (vm_address_t)address, size, FALSE, PROT_READ | PROT_WRITE);
    
    // නව bytes ටික memory එකට ලියන්න
    memcpy((void*)address, bytes, size);
    
    // නැවත සාමාන්‍ය තත්ත්වයට පත් කිරීම
    vm_protect(mach_task_self(), (vm_address_t)address, size, FALSE, PROT_READ | PROT_EXEC);
}

uintptr_t get_GameModule_Base(const char* moduleName) {
    uint32_t count = _dyld_image_count();
    for (uint32_t i = 0; i < count; i++) {
        const char* name = _dyld_get_image_name(i);
        if (name && strstr(name, moduleName)) {
            // Type cast එකක් යොදා නිවැරදි කර ඇත
            return (uintptr_t)_dyld_get_image_header(i);
        }
    }
    return 0;
}

// NakanoYotsuba.h ගොනුවේ getRealOffset දැනටමත් අඩංගු නිසා මෙහි ගැටලුවක් මතු වුවහොත් මෙම ශ්‍රිතය මකා දැමිය හැක
uintptr_t getLocalRealOffset(uintptr_t offset) {
    static uintptr_t base = 0;
    if (base == 0) {
        base = get_GameModule_Base("GameAssembly.dylib"); 
    }
    return base + offset;
}

#define kWidth  [UIScreen mainScreen].bounds.size.width
#define kHeight [UIScreen mainScreen].bounds.size.height
#define kScale [UIScreen mainScreen].scale

struct Vector3 {
    float x, y, z;
    Vector3() : x(0), y(0), z(0) {}
    Vector3(float x1, float y1, float z1) : x(x1), y(y1), z(z1) {}
    float Distance(Vector3 v) {
        return sqrtf(powf(v.x - x, 2) + powf(v.y - y, 2) + powf(v.z - z, 2));
    }
};

struct Matrix4x4 {
    float m[4][4];
};

static bool MenDeal = true; 

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

// KeyAuth Config
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

// Hack Variables
static bool streamProof = true; 
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

    if (masterAimbot && aimbotEnable) { } 
    if (enemyEsp) { }

    // Ambiguous Error එක මඟහැරීමට මෙහි getRealOffset වෙනුවට getLocalRealOffset යොදා ඇත
    
    // 1. No Recoil
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

    // 2. Fast Swap
    static bool lastFastSwap = false;
    if (fastSwap != lastFastSwap) {
        uintptr_t addr = getLocalRealOffset(OFFSET_FAST_SWAP);
        if (fastSwap) {
            const uint8_t patch[] = { 0x00, 0x00, 0x00, 0x00 }; 
            safePatchMemory(addr, patch, sizeof(patch));
        } else {
            const uint8_t restore[] = { 0x00, 0x00, 0x00, 0x00 }; 
            safePatchMemory(addr, restore, sizeof(restore));
        }
        lastFastSwap = fastSwap;
    }

    // 3. Fast Reload
    static bool lastFastReload = false;
    if (fastReload != lastFastReload) {
        uintptr_t addr = getLocalRealOffset(OFFSET_FAST_RELOAD);
        if (fastReload) {
            const uint8_t patch[] = { 0x00, 0x00, 0x00, 0x00 }; 
            safePatchMemory(addr, patch, sizeof(patch));
        } else {
            const uint8_t restore[] = { 0x00, 0x00, 0x00, 0x00 }; 
            safePatchMemory(addr, restore, sizeof(restore));
        }
        lastFastReload = fastReload;
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

- (instancetype)initWithNibName:(nullable NSString *)nibNameOrNil bundle:(nullable NSBundle *)nibBundleOrNil {
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    _device = MTLCreateSystemDefaultDevice();
    _commandQueue = [_device newCommandQueue];
    if (!self.device) abort();
    
    IMGUI_CHECKVERSION();
    ImGui::CreateContext();
    ImGuiIO& io = ImGui::GetIO();
    io.GetClipboardTextFn = GetClipboardTextFn;
    io.SetClipboardTextFn = SetClipboardTextFn;
    
    io.Fonts->AddFontFromMemoryCompressedTTF((void*)Honkai_compressed_data, Honkai_compressed_size, 45.0f, NULL, io.Fonts->GetGlyphRangesDefault());
    ImGui_ImplMetal_Init(_device);
    return self;
}

+ (void)showChange:(BOOL)open {
    MenDeal = !isKeyAuthLogged ? true : open;
}

- (void)loadView {
    CGFloat w = [UIApplication sharedApplication].windows[0].rootViewController.view.frame.size.width;
    CGFloat h = [UIApplication sharedApplication].windows[0].rootViewController.view.frame.size.height;
    
    self.view = [[UIView alloc] initWithFrame:CGRectMake(0, 0, w, h)];
    self.view.backgroundColor = [UIColor clearColor];
    
    self.secureContainerField = [[UITextField alloc] initWithFrame:self.view.bounds];
    self.secureContainerField.backgroundColor = [UIColor clearColor];
    self.secureContainerField.secureTextEntry = streamProof;
    self.secureContainerField.userInteractionEnabled = YES;
    [self.view addSubview:self.secureContainerField];
    
    UIView *secureLayer = self.secureContainerField.subviews.firstObject ?: self.secureContainerField;
    secureLayer.userInteractionEnabled = YES;
    
    self.mtkViewObj = [[MTKView alloc] initWithFrame:self.view.bounds];
    self.mtkViewObj.clearColor = MTLClearColorMake(0, 0, 0, 0);
    self.mtkViewObj.backgroundColor = [UIColor clearColor];
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
    
    if (anyTouch.phase == UITouchPhaseBegan && !ImGui::IsAnyItemActive() && !ImGui::IsWindowHovered(ImGuiHoveredFlags_AnyWindow)) {
        [self.view endEditing:YES];
        [hiddenTextField resignFirstResponder];
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
    io.DeltaTime = 1.0f / float(view.preferredFramesPerSecond ?: 120);
    
    static bool wasWantTextInput = false;
    if (io.WantTextInput && !wasWantTextInput) {
        [hiddenTextField becomeFirstResponder];
    } else if (!io.WantTextInput && wasWantTextInput) {
        [hiddenTextField resignFirstResponder];
        hiddenTextField.text = @""; 
    }
    wasWantTextInput = io.WantTextInput;
    self.secureContainerField.secureTextEntry = streamProof;

    id<MTLCommandBuffer> commandBuffer = [self.commandQueue commandBuffer];
    if (!isKeyAuthLogged) {
        [self.view setUserInteractionEnabled:YES];
    } else {
        [self.view setUserInteractionEnabled:(MenDeal ? YES : NO)];
        UpdateHacks();
    }

    MTLRenderPassDescriptor* renderPassDescriptor = view.currentRenderPassDescriptor;
    if (renderPassDescriptor != nil) {
        id <MTLRenderCommandEncoder> renderEncoder = [commandBuffer renderCommandEncoderWithDescriptor:renderPassDescriptor];
        [renderEncoder pushDebugGroup:@"ImGui Premium Cyber Login"];

        ImGui_ImplMetal_NewFrame(renderPassDescriptor);
        ImGui::NewFrame();
        
        ImGuiStyle* style = &ImGui::GetStyle();
        style->WindowRounding = 12.0f; style->FrameRounding = 6.0f;        
        style->GrabRounding = 10.0f; style->PopupRounding = 6.0f;
        style->ChildRounding = 8.0f; style->WindowPadding = ImVec2(14, 14); 
        style->FramePadding = ImVec2(10, 8); style->ItemSpacing = ImVec2(10, 10);
        style->WindowBorderSize = 1.0f; style->FrameBorderSize = 1.0f;

        ImVec4* colors = style->Colors;
        colors[ImGuiCol_WindowBg] = ImVec4(0.06f, 0.07f, 0.10f, menuTransparency); 
        colors[ImGuiCol_ChildBg] = ImVec4(0.09f, 0.10f, 0.14f, 0.60f); 
        colors[ImGuiCol_FrameBg] = ImVec4(0.11f, 0.13f, 0.18f, 1.00f); 
        
        ImVec4 customAccent = ImVec4(menuAccentColor[0], menuAccentColor[1], menuAccentColor[2], menuAccentColor[3]);
        colors[ImGuiCol_Border] = ImVec4(customAccent.x, customAccent.y, customAccent.z, 0.40f); 
        colors[ImGuiCol_CheckMark] = customAccent;
        colors[ImGuiCol_SliderGrab] = customAccent;
        colors[ImGuiCol_Button] = ImVec4(customAccent.x, customAccent.y, customAccent.z, 0.15f); 
        colors[ImGuiCol_Text] = ImVec4(0.92f, 0.94f, 0.98f, 1.00f); 
        
        ImFont* font = ImGui::GetFont();
        font->Scale = 14.f / font->FontSize;
        
        // LOGIN SCREEN
        if (!isKeyAuthLogged) {
            ImGui::SetNextWindowPos(ImVec2((view.bounds.size.width - 360) / 2, (view.bounds.size.height - 280) / 2), ImGuiCond_Always);
            ImGui::SetNextWindowSize(ImVec2(360, 280), ImGuiCond_Always);
            ImGui::Begin("LOGIN_SYSTEM", NULL, ImGuiWindowFlags_NoCollapse | ImGuiWindowFlags_NoTitleBar | ImGuiWindowFlags_NoResize | ImGuiWindowFlags_NoMove);
            
            ImDrawList* drawList = ImGui::GetWindowDrawList();
            ImVec2 pos = ImGui::GetWindowPos();
            drawList->AddRectFilled(pos, ImVec2(pos.x + 360, pos.y + 65), ImColor(15, 18, 25, 255), 12.0f);
            
            ImGui::SetCursorPos(ImVec2(20, 18));
            Draw3DAnimatedText(drawList, font, 24.0f, ImGui::GetCursorScreenPos(), "STATISTICS KING", customAccent, false);
            ImGui::Dummy(ImVec2(0, 30)); 
            
            ImGui::SetCursorPos(ImVec2(20, 48));
            ImGui::TextDisabled("PREMIUM ACCESS");
            ImGui::SetCursorPosY(85);
            
            ImGui::TextDisabled("Username:");
            ImGui::SetNextItemWidth(260); 
            ImGui::InputText("##UserField", usernameInput, IM_ARRAYSIZE(usernameInput));
            
            ImGui::Spacing();
            ImGui::TextDisabled("Password:");
            ImGui::SetNextItemWidth(260); 
            ImGui::InputText("##PassField", passwordInput, IM_ARRAYSIZE(passwordInput), ImGuiInputTextFlags_Password);
            
            ImGui::Spacing(); ImGui::Separator(); ImGui::Spacing();
            
            if (isAuthenticating) {
                ImGui::Button("Authenticating Please Wait...", ImVec2(-1, 42));
            } else {
                if (ImGui::Button("Login to System", ImVec2(-1, 42))) {
                    NSString *uStr = [NSString stringWithUTF8String:usernameInput];
                    NSString *pStr = [NSString stringWithUTF8String:passwordInput];
                    if (uStr.length > 0 && pStr.length > 0) {
                        isAuthenticating = true; loginErrorMessage = "";
                        [hiddenTextField resignFirstResponder];
                        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                            BOOL success = [self performUserPassLogin:uStr pwd:pStr];
                            dispatch_async(dispatch_get_main_queue(), ^{
                                isAuthenticating = false;
                                if (success) isKeyAuthLogged = true;
                            });
                        });
                    }
                }
            }
            if (!loginErrorMessage.empty()) {
                ImGui::TextColored(ImVec4(1.0f, 0.3f, 0.3f, 1.0f), "[Error] %s", loginErrorMessage.c_str());
            }
            ImGui::End();
        } 
        // MAIN MENU SCREEN
        else if (MenDeal == true) {
            ImGui::SetNextWindowPos(ImVec2((view.bounds.size.width - 540) / 2, (view.bounds.size.height - 350) / 2), ImGuiCond_FirstUseEver);
            ImGui::SetNextWindowSize(ImVec2(540, 350), ImGuiCond_FirstUseEver); 
            ImGui::Begin("STATISTICS_MAIN_CONTAINER", &MenDeal, ImGuiWindowFlags_NoCollapse | ImGuiWindowFlags_NoTitleBar | ImGuiWindowFlags_NoResize);
            
            ImGui::Columns(2, "MainLayout", false);
            ImGui::SetColumnWidth(0, 140.0f); 
            ImGui::BeginChild("Sidebar", ImVec2(0, 0), true);
            
            static int activeTab = 0; 
            const char* tabs[] = { " Aimbot", " Visuals", " Misc", " Settings" };
            for (int i = 0; i < 4; i++) {
                if (ImGui::Button(tabs[i], ImVec2(120, 38))) activeTab = i;
            }
            ImGui::EndChild();
            ImGui::NextColumn();
            
            ImGui::BeginChild("ContentArea", ImVec2(0, 0), false);
            if (activeTab == 0) {
                ImGui::Checkbox("Master Switch", &masterAimbot);
                ImGui::Checkbox("Enabled", &aimbotEnable);
                ImGui::SliderFloat("FOV Circle", &fovRadius, 1.0f, 360.0f);
            } else if (activeTab == 1) {
                ImGui::Checkbox("Enemy ESP", &enemyEsp);
                ImGui::Checkbox("Line", &espLine);
                ImGui::Checkbox("Box", &espBox);
            } else if (activeTab == 2) {
                ImGui::Checkbox("No Recoil", &noRecoil);
                ImGui::Checkbox("Fast Swap Weapon", &fastSwap);
                ImGui::Checkbox("Fast Reload", &fastReload);
            } else if (activeTab == 3) {
                ImGui::Checkbox("Stream Proof", &streamProof);
                ImGui::SliderFloat("Transparency", &menuTransparency, 0.3f, 1.0f);
            }
            ImGui::EndChild();
            ImGui::Columns(1);
            ImGui::End();
        }
        
        // FOV Circle drawing
        if (isKeyAuthLogged && aimbotEnable && showFovCircle) {
            ImVec2 center = ImVec2(io.DisplaySize.x / 2.0f, io.DisplaySize.y / 2.0f);
            ImGui::GetBackgroundDrawList()->AddCircle(center, fovRadius * 3.0f, ImColor(customAccent.x, customAccent.y, customAccent.z, 0.8f), 100, 1.2f);
        }

        ImGui::Render();
        ImGui_ImplMetal_RenderDrawData(ImGui::GetDrawData(), commandBuffer, renderEncoder);
        [renderEncoder popDebugGroup];
        [renderEncoder endEncoding];
        [commandBuffer presentDrawable:view.currentDrawable];
    }
    [commandBuffer commit];
}

- (void)mtkView:(MTKView*)view drawableSizeWillChange:(CGSize)size {}
@end
