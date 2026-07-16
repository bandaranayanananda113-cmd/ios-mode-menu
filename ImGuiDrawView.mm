#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

// Imgui library
#import "Esp/CaptainHook.h"
#import "Esp/ImGuiDrawView.h"
#import "IMGUI/imgui.h"
#import "IMGUI/imgui_internal.h" // InputText active state චෙක් කරන්න ඕනේ නිසා
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

// ගේම් එක ලෝඩ් වෙද්දීම මෙනු එක අනිවාර්යයෙන්ම ඕපන් වෙන්න මෙතන true කරනවා
static bool MenDeal = true; 

// ==========================================
// KEYAUTH DETAILS (Web API Method)
// ==========================================
static NSString *const kaName = @"EXLITER PRO";
static NSString *const kaOwnerId = @"JU1KcBIQwE";
static NSString *const kaSecret = @"b0ffff3c2299551401bdfcf35ea9be8283c0aab612cc0241c5d813e4f0f2a393";
static NSString *const kaVersion = @"1.0";

static bool isKeyAuthLogged = false;
static char licenseKeyInput[128] = ""; 
static std::string subExpiryDate = "N/A";
static std::string subDaysRemaining = "0";
static std::string loginErrorMessage = "";
static bool isAuthenticating = false;

// ==========================================
// CHEAT VARIABLES
// ==========================================
static bool aimbotEnable = false;
static bool showFovCircle = false;
static bool ignoreInvisible = false;
static bool ignoreKnocked = false;
static bool forceLock = false;
static int selectedHitbox = 0; 

static bool enemyEsp = false;
static bool espLine = false;
static bool useFireMaterial = false;
static bool espBox = false;
static bool espHealth = false;
static bool espNickname = false;
static bool espDistance = false;
static bool nearbyCount = false;
static float counterTextSize = 25.0f;
static float counterColor[4] = {1.0f, 0.0f, 0.0f, 1.0f}; 

static bool noFog = false;
static bool noFpsLimit = false;
static bool noWeaponSpread = false;

// Premium Cyan Theme Color
static float menuAccentColor[4] = {0.00f, 1.00f, 0.88f, 1.00f}; // Cyber Neon Cyan (#00FFE0)

static bool aimbot_active = false;
static bool esp_active = false;

// Hidden Dummy TextField for iOS Keyboard Trigger
static UITextField *hiddenTextField = nil;

@interface ImGuiDrawView () <MTKViewDelegate>
@property (nonatomic, strong) id <MTLDevice> device;
@property (nonatomic, strong) id <MTLCommandQueue> commandQueue;
@end

@implementation ImGuiDrawView

// ==========================================
// NATIVE KEYAUTH LOGIN LOGIC
// ==========================================
- (BOOL)performKeyAuthLogin:(NSString *)userKey {
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
        loginErrorMessage = initJson[@"message"] ? [initJson[@"message"] UTF8String] : "Server Connection Failed.";
        return NO;
    }
    
    NSString *sessionId = initJson[@"sessionid"];
    if (!sessionId) return NO;
    
    NSMutableURLRequest *loginRequest = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:apiUrl]];
    [loginRequest setHTTPMethod:@"POST"];
    NSString *loginPostData = [NSString stringWithFormat:@"type=license&key=%@&sessionid=%@&name=%@&ownerid=%@", userKey, sessionId, kaName, kaOwnerId];
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
        return YES;
    } else {
        loginErrorMessage = loginJson[@"message"] ? [loginJson[@"message"] UTF8String] : "Invalid Key.";
        return NO;
    }
}

bool (*old_get_IsAiming)(void *instance);
bool new_get_IsAiming(void *instance) {
    return true; 
}

void (*huy)(void *instance);
void _huy(void *instance) {
    huy(instance);
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
    
    ImFont* font = io.Fonts->AddFontFromMemoryCompressedTTF((void*)Honkai_compressed_data, Honkai_compressed_size, 45.0f, NULL, io.Fonts->GetGlyphRangesDefault());
    ImGui_ImplMetal_Init(_device);
    
    return self;
}

+ (void)showChange:(BOOL)open
{
    // ලොගින් වෙලා නැත්නම් ගේම් එක ඇතුලේදී මෙනු එක වහන්න දෙන්නේ නැහැ
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

    // iOS Keyboard එක Force ඕපන් කරන්න හදන Hidden TextField එක
    hiddenTextField = [[UITextField alloc] initWithFrame:CGRectZero];
    hiddenTextField.keyboardType = UIKeyboardTypeASCIICapable;
    hiddenTextField.hidden = YES;
    [self.view addSubview:hiddenTextField];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillShow:) name:UIKeyboardWillShowNotification object:nil];
}

- (void)keyboardWillShow:(NSNotification *)notification {
    // Keyboard එක ඕපන් වෙද්දී ImGui එකට input focus එක දෙනවා
}

#pragma mark - Interaction
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
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event { 
    [self updateIOWithTouchEvent:event]; 
}
- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event { [self updateIOWithTouchEvent:event]; }
- (void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event { [self updateIOWithTouchEvent:event]; }
- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event { [self updateIOWithTouchEvent:event]; }

#pragma mark - MTKViewDelegate

- (void)drawInMTKView:(MTKView*)view
{
    ImGuiIO& io = ImGui::GetIO();
    io.DisplaySize.x = view.bounds.size.width;
    io.DisplaySize.y = view.bounds.size.height;

    CGFloat framebufferScale = view.window.screen.scale ?: UIScreen.mainScreen.scale;
    io.DisplayFramebufferScale = ImVec2(framebufferScale, framebufferScale);
    io.DeltaTime = 1 / float(view.preferredFramesPerSecond ?: 120);
    
    id<MTLCommandBuffer> commandBuffer = [self.commandQueue commandBuffer];
    
    // ලොගින් වෙනකම් Touch Controls 100% ක් මෙනු එකට විතරක් සීමා කරනවා (ගේම් එක ක්ලික් කරන්න බෑ)
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
        
        // ==========================================
        // CYBERPUNK PREMIUM STYLING
        // ==========================================
        ImGuiStyle* style = &ImGui::GetStyle();
        style->WindowRounding = 10.0f;       
        style->FrameRounding = 6.0f;        
        style->GrabRounding = 6.0f;
        style->PopupRounding = 6.0f;
        style->ChildRounding = 8.0f;
        style->WindowPadding = ImVec2(0, 0); 
        style->FramePadding = ImVec2(12, 10);
        style->ItemSpacing = ImVec2(10, 12);
        style->WindowBorderSize = 1.5f; // Border එකක් දාලා Glow කරවන්න

        ImVec4* colors = style->Colors;
        colors[ImGuiCol_WindowBg]               = ImVec4(0.05f, 0.06f, 0.09f, 0.98f); // Deep Space Black
        colors[ImGuiCol_ChildBg]                = ImVec4(0.08f, 0.09f, 0.13f, 0.70f);
        colors[ImGuiCol_FrameBg]                = ImVec4(0.12f, 0.14f, 0.18f, 1.00f);
        colors[ImGuiCol_FrameBgHovered]         = ImVec4(0.16f, 0.19f, 0.24f, 1.00f);
        colors[ImGuiCol_FrameBgActive]          = ImVec4(0.20f, 0.24f, 0.30f, 1.00f);
        
        ImVec4 customAccent = ImVec4(menuAccentColor[0], menuAccentColor[1], menuAccentColor[2], menuAccentColor[3]);
        colors[ImGuiCol_Border]                 = customAccent; // Border එක Cyber Cyan වෙනවා
        colors[ImGuiCol_CheckMark]              = customAccent;
        colors[ImGuiCol_SliderGrab]             = customAccent;
        colors[ImGuiCol_SliderGrabActive]       = ImVec4(customAccent.x + 0.1f, customAccent.y + 0.1f, customAccent.z + 0.1f, 1.0f);
        colors[ImGuiCol_Button]                 = ImVec4(customAccent.x, customAccent.y, customAccent.z, 0.15f); // Soft Glow Buttons
        colors[ImGuiCol_ButtonHovered]          = ImVec4(customAccent.x, customAccent.y, customAccent.z, 0.35f);
        colors[ImGuiCol_ButtonActive]           = ImVec4(customAccent.x, customAccent.y, customAccent.z, 0.50f);
        
        colors[ImGuiCol_Text]                   = ImVec4(0.95f, 0.98f, 1.00f, 1.00f);
        colors[ImGuiCol_TextDisabled]           = ImVec4(0.45f, 0.55f, 0.65f, 1.00f);
        
        ImFont* font = ImGui::GetFont();
        font->Scale = 14.f / font->FontSize;
        
        // ==========================================
        // SCREEN 1: CYBERPUNK LOGIN (ONLY IF NOT LOGGED IN)
        // ==========================================
        if (!isKeyAuthLogged) 
        {
            // ගේම් එකේ මැදටම Lock කරනවා
            CGFloat loginWidth = 380;
            CGFloat loginHeight = 310;
            CGFloat lx = (view.bounds.size.width - loginWidth) / 2;
            CGFloat ly = (view.bounds.size.height - loginHeight) / 2;
            
            ImGui::SetNextWindowPos(ImVec2(lx, ly), ImGuiCond_Always);
            ImGui::SetNextWindowSize(ImVec2(loginWidth, loginHeight), ImGuiCond_Always);
            
            ImGuiWindowFlags login_flags = ImGuiWindowFlags_NoCollapse | ImGuiWindowFlags_NoTitleBar | ImGuiWindowFlags_NoResize | ImGuiWindowFlags_NoSavedSettings | ImGuiWindowFlags_NoMove;
            
            ImGui::Begin("CYBER_LOGIN", NULL, login_flags);
            
            // --- TOP HEADER BAR WITH CHROME DOTS (Premium Look) ---
            ImDrawList* drawList = ImGui::GetWindowDrawList();
            ImVec2 pos = ImGui::GetWindowPos();
            
            // Title Background
            drawList->AddRectFilled(pos, ImVec2(pos.x + loginWidth, pos.y + 35), ImColor(11, 14, 22, 255), 10.0f, ImDrawCornerFlags_Top);
            
            // Premium Mac-style Dot Buttons
            drawList->AddCircleFilled(ImVec2(pos.x + 20, pos.y + 18), 5.0f, ImColor(255, 95, 82, 255));   // Red
            drawList->AddCircleFilled(ImVec2(pos.x + 35, pos.y + 18), 5.0f, ImColor(255, 189, 46, 255));  // Yellow
            drawList->AddCircleFilled(ImVec2(pos.x + 50, pos.y + 18), 5.0f, ImColor(40, 201, 64, 255));   // Green
            
            // Title Text
            ImGui::SetCursorPos(ImVec2(0, 8));
            ImGui::SetWindowFontScale(0.95f);
            ImGui::TextColored(customAccent, "               IVANE MODE V5  |  SECURE BY KEYAUTH");
            ImGui::SetWindowFontScale(1.0f);
            
            ImGui::SetCursorPosY(45);
            ImGui::Spacing();
            
            ImGui::BeginChild("LoginMain", ImVec2(loginWidth - 20, loginHeight - 65), true);
            
            ImGui::Spacing();
            ImGui::TextDisabled("ENTER LICENSE KEY TO ACCESS THE CHEAT:");
            ImGui::Spacing();
            
            // Keyboard Popup Fix: Input Text එක ඇක්ටිව් වුණොත් iOS Keyboard එක force කරනවා
            ImGui::PushStyleColor(ImGuiCol_FrameBg, ImVec4(0.05f, 0.06f, 0.08f, 1.00f));
            if (ImGui::InputText("##LicenseField", licenseKeyInput, IM_ARRAYSIZE(licenseKeyInput))) {
                // Typing..
            }
            ImGui::PopStyleColor();
            
            if (ImGui::IsItemActive()) {
                if (![hiddenTextField isFirstResponder]) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [hiddenTextField becomeFirstResponder];
                    });
                }
            }
            
            ImGui::Spacing();
            
            // --- 💡 ONE-TAP PASTE FROM CLIPBOARD BUTTON (For iOS Ease) ---
            if (ImGui::Button("📋 PASTE KEY FROM CLIPBOARD", ImVec2(ImGui::GetContentRegionAvailWidth(), 35))) {
                UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
                if (pasteboard.string) {
                    strncpy(licenseKeyInput, [pasteboard.string UTF8String], sizeof(licenseKeyInput) - 1);
                }
            }
            
            ImGui::Spacing();
            ImGui::Separator();
            ImGui::Spacing();
            
            // Action Buttons
            if (isAuthenticating) {
                ImGui::Button("AUTHENTICATING... PLEASE WAIT", ImVec2(200, 40));
            } else {
                if (ImGui::Button("AUTHENTICATE", ImVec2(200, 40))) {
                    NSString *userKey = [NSString stringWithUTF8String:licenseKeyInput];
                    if (userKey.length > 0) {
                        isAuthenticating = true;
                        loginErrorMessage = "";
                        
                        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                            BOOL success = [self performKeyAuthLogin:userKey];
                            dispatch_async(dispatch_get_main_queue(), ^{
                                isAuthenticating = false;
                                if (success) {
                                    isKeyAuthLogged = true;
                                    [hiddenTextField resignFirstResponder];
                                }
                            });
                        });
                    } else {
                        loginErrorMessage = "Please enter or paste a key first!";
                    }
                }
            }
            
            ImGui::SameLine();
            if (ImGui::Button("CANCEL / TG", ImVec2(ImGui::GetContentRegionAvailWidth(), 40))) {
                [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"https://t.me/cosmosdemo"] options:@{} completionHandler:nil];
            }
            
            // Errors
            if (!loginErrorMessage.empty()) {
                ImGui::Spacing();
                ImGui::TextColored(ImVec4(1.0f, 0.3f, 0.3f, 1.0f), "⚠️ %s", loginErrorMessage.c_str());
            }
            
            ImGui::EndChild();
            ImGui::End();
        } 
        
        // ==========================================
        // SCREEN 2: MAIN MENU (SUCCESSFULLY LOGGED IN)
        // ==========================================
        else if (MenDeal == true) 
        {
            CGFloat menuWidth = 500;
            CGFloat menuHeight = 340;
            CGFloat mx = (view.bounds.size.width - menuWidth) / 2;
            CGFloat my = (view.bounds.size.height - menuHeight) / 2;
            
            ImGui::SetNextWindowPos(ImVec2(mx, my), ImGuiCond_FirstUseEver);
            ImGui::SetNextWindowSize(ImVec2(menuWidth, menuHeight), ImGuiCond_FirstUseEver); 
            
            ImGuiWindowFlags window_flags = ImGuiWindowFlags_NoCollapse | ImGuiWindowFlags_NoTitleBar | ImGuiWindowFlags_NoResize | ImGuiWindowFlags_NoSavedSettings;
            ImGui::Begin("COSMOS PRIVATE MENU", &MenDeal, window_flags);
            
            ImGui::Columns(2, "MainLayout", false);
            ImGui::SetColumnWidth(0, 130.0f); 
            
            // LEFT SIDEBAR
            ImGui::PushStyleColor(ImGuiCol_ChildBg, ImVec4(0.03f, 0.04f, 0.06f, 1.00f)); 
            ImGui::BeginChild("Sidebar", ImVec2(0, 0), true);
            
            ImGui::Spacing(); ImGui::Spacing();
            ImGui::TextColored(customAccent, "  IVANE V5");
            ImGui::Separator();
            ImGui::Spacing();

            static int activeTab = 0; 
            const char* tabs[] = { " Aimbot", " Visuals", " Misc", " Settings" };
            
            for (int i = 0; i < 4; i++) {
                bool is_selected = (activeTab == i);
                if (is_selected) {
                    ImGui::PushStyleColor(ImGuiCol_Button, ImVec4(customAccent.x, customAccent.y, customAccent.z, 0.15f));
                    ImGui::PushStyleColor(ImGuiCol_ButtonHovered, ImVec4(customAccent.x, customAccent.y, customAccent.z, 0.20f));
                    ImGui::PushStyleColor(ImGuiCol_ButtonActive, ImVec4(customAccent.x, customAccent.y, customAccent.z, 0.25f));
                    ImGui::PushStyleColor(ImGuiCol_Text, customAccent);
                } else {
                    ImGui::PushStyleColor(ImGuiCol_Button, ImVec4(0, 0, 0, 0));
                    ImGui::PushStyleColor(ImGuiCol_ButtonHovered, ImVec4(1, 1, 1, 0.04f));
                    ImGui::PushStyleColor(ImGuiCol_ButtonActive, ImVec4(1, 1, 1, 0.06f));
                    ImGui::PushStyleColor(ImGuiCol_Text, ImVec4(0.6f, 0.65f, 0.7f, 1.00f));
                }

                if (ImGui::Button(tabs[i], ImVec2(110, 35))) {
                    activeTab = i;
                }
                ImGui::PopStyleColor(4);
                ImGui::Spacing();
            }
            ImGui::EndChild();
            ImGui::PopStyleColor(); 

            ImGui::NextColumn();
            
            // RIGHT CONTENT AREA
            ImGui::BeginChild("ContentArea", ImVec2(0, 0), false);
            
            ImGui::Spacing();
            
            if (ImGui::Button("@cosmos", ImVec2(75, 22))) {
                [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"https://t.me/cosmosdemo"] options:@{} completionHandler:nil];
            }
            
            ImGui::SameLine(ImGui::GetWindowWidth() - 35);
            if (ImGui::Button("X", ImVec2(22, 22))) {
                MenDeal = false;
            }
            ImGui::Separator();
            ImGui::Spacing();

            // 1. AIMBOT TAB
            if (activeTab == 0) { 
                ImGui::TextColored(customAccent, "AIMBOT"); 
                ImGui::Spacing();
                
                ImGui::Checkbox("Aimbot", &aimbotEnable);
                ImGui::Checkbox("Show FOV circle", &showFovCircle);
                ImGui::Checkbox("Ignore invisible targets", &ignoreInvisible);
                ImGui::Checkbox("Ignore knocked targets", &ignoreKnocked);
                ImGui::Checkbox("Force lock", &forceLock);
                
                ImGui::Spacing();
                ImGui::Text("Hitbox");
                const char* hitboxes[] = { "Nearest", "Head", "Neck", "Body" };
                ImGui::Combo("##HitboxCombo", &selectedHitbox, hitboxes, IM_ARRAYSIZE(hitboxes));
            } 
            // 2. VISUALS TAB
            else if (activeTab == 1) { 
                ImGui::TextColored(customAccent, "VISUALS");
                ImGui::Spacing();
                
                ImGui::Checkbox("Enemy ESP", &enemyEsp);
                ImGui::Checkbox("Line", &espLine);
                ImGui::Checkbox("Use fire material", &useFireMaterial);
                ImGui::Checkbox("Box", &espBox);
                ImGui::Checkbox("Health", &espHealth);
                ImGui::Checkbox("Nickname", &espNickname);
                ImGui::Checkbox("Distance", &espDistance);
                ImGui::Checkbox("Nearby enemies count", &nearbyCount);
                
                ImGui::Spacing();
                ImGui::Text("Counter text color");
                ImGui::SameLine();
                ImGui::ColorEdit4("##CounterColor", counterColor, ImGuiColorEditFlags_NoInputs | ImGuiColorEditFlags_NoLabel);
                
                ImGui::SliderFloat("Counter text size", &counterTextSize, 10.0f, 50.0f, "%.1fpx");
            } 
            // 3. MISC TAB
            else if (activeTab == 2) { 
                ImGui::TextColored(customAccent, "MISC");
                ImGui::Spacing();
                
                ImGui::Checkbox("No fog", &noFog);
                ImGui::Checkbox("No FPS limit", &noFpsLimit);
                ImGui::Checkbox("No weapon spread", &noWeaponSpread);
            } 
            // 4. SETTINGS TAB
            else if (activeTab == 3) { 
                ImGui::TextColored(customAccent, "SETTINGS & SECURITY");
                ImGui::Spacing();
                
                ImGui::Text("Menu Accent Color:");
                ImGui::SameLine();
                ImGui::ColorEdit4("##AccentColorPicker", menuAccentColor, ImGuiColorEditFlags_NoInputs);
                
                ImGui::Spacing();
                ImGui::Separator();
                ImGui::Spacing();
                
                ImGui::TextColored(customAccent, "SUBSCRIPTION DETAILS");
                ImGui::Text("User Status: Active VIP");
                ImGui::Text("License Key: %s", licenseKeyInput);
                
                if (subExpiryDate != "N/A") {
                    time_t rawtime = std::stoll(subExpiryDate);
                    struct tm * timeinfo = localtime(&rawtime);
                    char buffer[80];
                    strftime(buffer, sizeof(buffer), "%Y-%m-%d %H:%M:%S", timeinfo);
                    ImGui::Text("Expires: %s", buffer);
                    ImGui::Text("Time Left: %s", subDaysRemaining.c_str());
                } else {
                    ImGui::Text("Expires: Lifetime");
                }
            }
            
            ImGui::EndChild();
            ImGui::Columns(1); 
            ImGui::End();   
        }
        
        ImDrawList* draw_list = ImGui::GetBackgroundDrawList();
        
        // ==========================================
        // CHEAT LOGIC (Only runs if KeyAuth is Logged In)
        // ==========================================
        if (isKeyAuthLogged) {
            if(aimbotEnable){
                if(!aimbot_active){
                    DobbyHook((void *)(getRealOffset(ENCRYPTOFFSET("0x6C07BD8"))), (void *)new_get_IsAiming, (void **)&old_get_IsAiming);
                    aimbot_active = true;
                }
            } else {
                if(aimbot_active){
                    DobbyDestroy((void *)(getRealOffset(ENCRYPTOFFSET("0x6C07BD8"))));
                    aimbot_active = false;
                }
            }

            if(enemyEsp){
                if(!esp_active){
                    vm_unity(ENCRYPTOFFSET("0x6F498D4"), strtoul(ENCRYPTHEX("0x010080D2"), nullptr, 0));
                    esp_active = true;
                }
            } else {
                if(esp_active){
                    vm_unity(ENCRYPTOFFSET("0x6F498D4"), strtoul(ENCRYPTHEX("0xF60302AA"), nullptr, 0));
                    esp_active = false;
                }
            }
                
            static dispatch_once_t onceToken;
            dispatch_once(&onceToken, ^{
                  DobbyHook((void *)(getRealOffset(ENCRYPTOFFSET("0x5F145F8"))), (void *)_huy, (void **)&huy);
            });

            if (aimbotEnable && showFovCircle) {
                ImVec2 center = ImVec2(io.DisplaySize.x / 2.0f, io.DisplaySize.y / 2.0f);
                draw_list->AddCircle(center, 120.0f, ImColor(customAccent.x, customAccent.y, customAccent.z, 0.8f), 100, 1.5f);
            }
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
