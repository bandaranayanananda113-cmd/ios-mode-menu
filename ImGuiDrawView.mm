#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

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
static bool masterAimbot = false;
static bool aimbotEnable = false;
static int selectedAimConfig = 0; 
static int selectedAimMethod = 0; // 0 = Silent Aim, 1 = Vector Aim
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

static float menuAccentColor[4] = {1.00f, 0.32f, 0.12f, 1.00f}; // Customizable Theme
static float menuTransparency = 0.90f;

// Hidden iOS TextField
static UITextField *hiddenTextField = nil;

// Backspace Fix tracker
static int holdBackspaceFrames = 0;

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
@end

@implementation ImGuiDrawView

// KeyAuth API Login with Username & Password
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
        
        [[NSUserDefaults standardUserDefaults] setObject:user forKey:@"CEYLON_USER"];
        [[NSUserDefaults standardUserDefaults] setObject:pass forKey:@"CEYLON_PASS"];
        [[NSUserDefaults standardUserDefaults] synchronize];
        
        return YES;
    } else {
        loginErrorMessage = loginJson[@"message"] ? [loginJson[@"message"] UTF8String] : "Invalid Credentials.";
        return NO;
    }
}

- (void)tryAutoLogin {
    NSString *savedUser = [[NSUserDefaults standardUserDefaults] stringForKey:@"CEYLON_USER"];
    NSString *savedPass = [[NSUserDefaults standardUserDefaults] stringForKey:@"CEYLON_PASS"];
    
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
                    [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"CEYLON_USER"];
                    [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"CEYLON_PASS"];
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

- (MTKView *)mtkView
{
    return (MTKView *)self.view;
}

- (void)loadView
{
    CGFloat w = [UIApplication sharedApplication].windows[0].rootViewController.view.frame.size.width;
    CGFloat h = [UIApplication sharedApplication].windows[0].rootViewController.view.frame.size.height;
    self.view = [[MTKView alloc] initWithFrame:CGRectMake(0, 0, w, h)];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.mtkView.device = self.device;
    self.mtkView.delegate = self;
    self.mtkView.clearColor = MTLClearColorMake(0, 0, 0, 0);
    self.mtkView.backgroundColor = [UIColor colorWithRed:0 green:0 blue:0 alpha:0];
    self.mtkView.clipsToBounds = YES;

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

// 100% Working Backspace Logic implemented here
- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string {
    ImGuiIO& io = ImGui::GetIO();
    
    if (string.length == 0) {
        holdBackspaceFrames = 3; // Hold backspace for 3 frames to ensure it deletes properly
    } else {
        for (int i = 0; i < string.length; i++) {
            io.AddInputCharacter([string characterAtIndex:i]);
        }
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

    // Apply backspace fix natively during rendering
    if (holdBackspaceFrames > 0) {
        io.KeysDown[ImGuiKey_Backspace] = true;
        if (io.KeyMap[ImGuiKey_Backspace] >= 0 && io.KeyMap[ImGuiKey_Backspace] < 512) {
            io.KeysDown[io.KeyMap[ImGuiKey_Backspace]] = true;
        }
        holdBackspaceFrames--;
    } else {
        io.KeysDown[ImGuiKey_Backspace] = false;
        if (io.KeyMap[ImGuiKey_Backspace] >= 0 && io.KeyMap[ImGuiKey_Backspace] < 512) {
            io.KeysDown[io.KeyMap[ImGuiKey_Backspace]] = false;
        }
    }
    
    static bool wasWantTextInput = false;
    if (io.WantTextInput && !wasWantTextInput) {
        [hiddenTextField becomeFirstResponder];
    } else if (!io.WantTextInput && wasWantTextInput) {
        [hiddenTextField resignFirstResponder];
        hiddenTextField.text = @""; 
    }
    wasWantTextInput = io.WantTextInput;

    id<MTLCommandBuffer> commandBuffer = [self.commandQueue commandBuffer];
    
    if (!isKeyAuthLogged) {
        [self.view setUserInteractionEnabled:YES];
    } else {
        [self.view setUserInteractionEnabled:(MenDeal ? YES : NO)];
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
            CGFloat loginWidth = 400;
            CGFloat loginHeight = 360; // Increased a bit for larger text space
            CGFloat lx = (view.bounds.size.width - loginWidth) / 2;
            CGFloat ly = (view.bounds.size.height - loginHeight) / 2;
            
            ImGui::SetNextWindowPos(ImVec2(lx, ly), ImGuiCond_Always);
            ImGui::SetNextWindowSize(ImVec2(loginWidth, loginHeight), ImGuiCond_Always);
            
            ImGuiWindowFlags login_flags = ImGuiWindowFlags_NoCollapse | ImGuiWindowFlags_NoTitleBar | ImGuiWindowFlags_NoResize | ImGuiWindowFlags_NoSavedSettings | ImGuiWindowFlags_NoMove;
            
            ImGui::Begin("LOGIN_SYSTEM", NULL, login_flags);
            
            ImDrawList* drawList = ImGui::GetWindowDrawList();
            ImVec2 pos = ImGui::GetWindowPos();
            
            drawList->AddRectFilled(pos, ImVec2(pos.x + loginWidth, pos.y + 60), ImColor(15, 18, 25, 255), 12.0f, ImDrawCornerFlags_All);
            drawList->AddLine(ImVec2(pos.x, pos.y + 60), ImVec2(pos.x + loginWidth, pos.y + 60), ImColor(customAccent.x, customAccent.y, customAccent.z, 0.8f), 2.0f);
            
            // Bigger Title in Login
            font->Scale = 22.f / font->FontSize; 
            ImGui::SetCursorPos(ImVec2(20, 18));
            ImGui::TextColored(customAccent, "CEYLON CHEAT");
            font->Scale = 14.f / font->FontSize; // Reset font scale
            
            ImGui::SetCursorPos(ImVec2(20, 42));
            ImGui::TextDisabled("PREMIUM ACCESS");
            
            ImGui::SetCursorPosY(85);
            
            ImGui::TextDisabled("Username:");
            ImGui::SetNextItemWidth(-1);
            ImGui::InputText("##UserField", usernameInput, IM_ARRAYSIZE(usernameInput));
            
            ImGui::Spacing();
            
            ImGui::TextDisabled("Password:");
            ImGui::SetNextItemWidth(-1);
            ImGui::InputText("##PassField", passwordInput, IM_ARRAYSIZE(passwordInput), ImGuiInputTextFlags_Password);
            
            ImGui::Spacing();
            ImGui::Separator();
            ImGui::Spacing();
            
            if (isAuthenticating) {
                ImGui::Button("Authenticating Please Wait...", ImVec2(-1, 42));
            } else {
                if (ImGui::Button("Login to System", ImVec2(200, 42))) {
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
                
                ImGui::SameLine();
                if (ImGui::Button("Register/Buy", ImVec2(-1, 42))) {
                    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"https://t.me/cosmosdemo"] options:@{} completionHandler:nil];
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
            ImGui::Begin("CEYLON_MAIN_CONTAINER", &MenDeal, window_flags);
            
            // --- HUGE TRANSPARENT WATERMARK DESIGN ---
            ImDrawList* internalDrawList = ImGui::GetWindowDrawList();
            ImVec2 windowPos = ImGui::GetWindowPos();
            ImVec2 windowSize = ImGui::GetWindowSize();
            
            std::string watermarkText = "CEYLON CHEAT";
            font->Scale = 55.f / font->FontSize; // Huge scale for watermark
            ImVec2 textSize = ImGui::CalcTextSize(watermarkText.c_str());
            
            ImVec2 textPos = ImVec2(
                windowPos.x + (windowSize.x - textSize.x) * 0.5f + 40.0f,
                windowPos.y + (windowSize.y - textSize.y) * 0.5f
            );
            
            internalDrawList->AddText(font, 55.f, textPos, ImColor(customAccent.x, customAccent.y, customAccent.z, 0.06f), watermarkText.c_str());
            font->Scale = 14.f / font->FontSize; // Reset to normal
            // ------------------------------------------

            ImGui::Columns(2, "MainLayout", false);
            ImGui::SetColumnWidth(0, 140.0f); 
            
            ImGui::PushStyleColor(ImGuiCol_ChildBg, ImVec4(0.05f, 0.06f, 0.09f, 0.90f)); 
            ImGui::BeginChild("Sidebar", ImVec2(0, 0), true);
            
            ImGui::Spacing();
            
            // Bigger Title on Top Left sidebar
            font->Scale = 16.f / font->FontSize;
            ImGui::SetCursorPosX(10);
            ImGui::TextColored(customAccent, "CEYLON");
            ImGui::SetCursorPosX(10);
            ImGui::TextColored(customAccent, "CHEAT");
            font->Scale = 14.f / font->FontSize;

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
                
                ImGui::Text("Menu Accent Color balance:");
                // FIXED COLOR PICKER - NO INPUTS AND CLEAN DESIGN
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
                    [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"CEYLON_USER"];
                    [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"CEYLON_PASS"];
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
