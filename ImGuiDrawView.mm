#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

// Imgui library
#import "Esp/CaptainHook.h"
#import "Esp/ImGuiDrawView.h"
#import "IMGUI/imgui.h"
#import "IMGUI/imgui_impl_metal.h"
#import "IMGUI/Honkai.h"

// Patch library
#import "5Toubun/NakanoIchika.h"
#import "5Toubun/NakanoNino.h"
#import "5Toubun/NakanoMiku.h"
#import "5Toubun/NakanoYotsuba.h"
#import "5Toubun/NakanoItsuki.h"
#import "5Toubun/dobby.h"

// ==========================================
// KEYAUTH C++ HEADER IMPORT
// ==========================================
// ඔයාගේ KeyAuth හෙඩර් ෆයිල් එකේ නම keyauth.hpp නෙමෙයි නම්, ඒ නමට වෙනස් කරන්න.
#include "KeyAuth/keyauth.hpp" 

#define kWidth  [UIScreen mainScreen].bounds.size.width
#define kHeight [UIScreen mainScreen].bounds.size.height
#define kScale [UIScreen mainScreen].scale

static bool MenDeal = true;

// ==========================================
// KEYAUTH INITIALIZATION & CREDENTIALS
// ==========================================
std::string name = "EXLITER PRO";
std::string ownerid = "JU1KcBIQwE";
std::string secret = "b0ffff3c2299551401bdfcf35ea9be8283c0aab612cc0241c5d813e4f0f2a393";
std::string version = "1.0";

// KeyAuth API Instance එක නිර්මාණය කිරීම
KeyAuth::api KeyAuthApp(name, ownerid, secret, version);

static bool isKeyAuthLogged = false;
static char licenseKeyInput[128] = ""; // User key එක ගහන තැන
static std::string subExpiryDate = "N/A";
static std::string subDaysRemaining = "0";

// ==========================================
// 1. AIMBOT VARIABLES (Image 6)
// ==========================================
static bool aimbotEnable = false;
static bool showFovCircle = false;
static bool ignoreInvisible = false;
static bool ignoreKnocked = false;
static bool forceLock = false;
static int selectedHitbox = 0; // 0: Nearest, 1: Head, 2: Neck, 3: Body

// ==========================================
// 2. VISUALS VARIABLES (Image 7)
// ==========================================
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

// ==========================================
// 3. MISC VARIABLES (Image 8)
// ==========================================
static bool noFog = false;
static bool noFpsLimit = false;
static bool noWeaponSpread = false;

// COLOR CUSTOMIZER
static float menuAccentColor[4] = {0.98f, 0.34f, 0.13f, 1.00f}; // Default: Orange

// Active Cheats State Tracking
static bool show_s0_active = false;
static bool aimbot_active = false;
static bool esp_active = false;

@interface ImGuiDrawView () <MTKViewDelegate>
@property (nonatomic, strong) id <MTLDevice> device;
@property (nonatomic, strong) id <MTLCommandQueue> commandQueue;
@end

@implementation ImGuiDrawView

bool (*old_get_IsAiming)(void *instance);
bool new_get_IsAiming(void *instance) {
    return true; 
}

void (*huy)(void *instance);
void _huy(void *instance)
{
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

    // ==========================================
    // KEYAUTH INITIAL CALL ON BOOT
    // ==========================================
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        KeyAuthApp.init(); // KeyAuth App එක initialize කිරීම (ලෝගින් වෙන්න කලින් අනිවාර්යයි)
    });

    return self;
}

+ (void)showChange:(BOOL)open
{
    MenDeal = open;
}

- (MTKView *)mtkView
{
    return (MTKView *)self.view;
}

- (void)loadView
{
    CGFloat w = [UIApplication sharedApplication].windows[0].rootViewController.view.frame.size.width;
    CGFloat h = [UIApplication sharedApplication].windows[0].rootViewController.view.frame.size.height;
    self.view = [[NSClassFromString(@"MTKView") alloc] initWithFrame:CGRectMake(0, 0, w, h)];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.mtkView.device = self.device;
    self.mtkView.delegate = self;
    self.mtkView.clearColor = MTLClearColorMake(0, 0, 0, 0);
    self.mtkView.backgroundColor = [UIColor colorWithRed:0 green:0 blue:0 alpha:0];
    self.mtkView.clipsToBounds = YES;
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

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event { [self updateIOWithTouchEvent:event]; }
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
    
    [self.view setUserInteractionEnabled:(MenDeal ? YES : NO)];

    MTLRenderPassDescriptor* renderPassDescriptor = view.currentRenderPassDescriptor;
    if (renderPassDescriptor != nil)
    {
        id <MTLRenderCommandEncoder> renderEncoder = [commandBuffer renderCommandEncoderWithDescriptor:renderPassDescriptor];
        [renderEncoder pushDebugGroup:@"ImGui KeyAuth Menu"];

        ImGui_ImplMetal_NewFrame(renderPassDescriptor);
        ImGui::NewFrame();
        
        // ==========================================
        // DYNAMIC PRESTIGE STYLING
        // ==========================================
        ImGuiStyle* style = &ImGui::GetStyle();
        style->WindowRounding = 12.0f;       
        style->FrameRounding = 8.0f;        
        style->GrabRounding = 8.0f;
        style->PopupRounding = 8.0f;
        style->ChildRounding = 10.0f;
        style->WindowPadding = ImVec2(0, 0); 
        style->FramePadding = ImVec2(12, 8);
        style->ItemSpacing = ImVec2(10, 10);

        ImVec4* colors = style->Colors;
        colors[ImGuiCol_WindowBg]               = ImVec4(0.04f, 0.05f, 0.07f, 0.98f);
        colors[ImGuiCol_ChildBg]                = ImVec4(0.07f, 0.08f, 0.12f, 0.50f);
        colors[ImGuiCol_FrameBg]                = ImVec4(0.10f, 0.12f, 0.16f, 1.00f);
        colors[ImGuiCol_FrameBgHovered]         = ImVec4(0.14f, 0.17f, 0.22f, 1.00f);
        colors[ImGuiCol_FrameBgActive]          = ImVec4(0.18f, 0.21f, 0.28f, 1.00f);
        
        ImVec4 customAccent = ImVec4(menuAccentColor[0], menuAccentColor[1], menuAccentColor[2], menuAccentColor[3]);
        colors[ImGuiCol_CheckMark]              = customAccent;
        colors[ImGuiCol_SliderGrab]             = customAccent;
        colors[ImGuiCol_SliderGrabActive]       = ImVec4(customAccent.x + 0.1f, customAccent.y + 0.1f, customAccent.z + 0.1f, 1.0f);
        colors[ImGuiCol_Button]                 = ImVec4(customAccent.x, customAccent.y, customAccent.z, 0.80f);
        colors[ImGuiCol_ButtonHovered]          = customAccent;
        colors[ImGuiCol_ButtonActive]           = ImVec4(customAccent.x - 0.1f, customAccent.y - 0.1f, customAccent.z - 0.1f, 1.0f);
        
        colors[ImGuiCol_Text]                   = ImVec4(0.93f, 0.95f, 0.98f, 1.00f);
        colors[ImGuiCol_TextDisabled]           = ImVec4(0.45f, 0.50f, 0.60f, 1.00f);
        colors[ImGuiCol_Border]                 = ImVec4(0.12f, 0.15f, 0.20f, 0.40f);
        
        ImFont* font = ImGui::GetFont();
        font->Scale = 14.f / font->FontSize;
        
        // Compact Menu Size setup
        CGFloat menuWidth = 500;
        CGFloat menuHeight = 340;
        CGFloat x = ([UIScreen mainScreen].bounds.size.width - menuWidth) / 2;
        CGFloat y = ([UIScreen mainScreen].bounds.size.height - menuHeight) / 2;
        
        ImGui::SetNextWindowPos(ImVec2(x, y), ImGuiCond_FirstUseEver);
        ImGui::SetNextWindowSize(ImVec2(menuWidth, menuHeight), ImGuiCond_FirstUseEver); 
        
        if (MenDeal == true)
        {     
            ImGuiWindowFlags window_flags = ImGuiWindowFlags_NoCollapse | ImGuiWindowFlags_NoTitleBar | ImGuiWindowFlags_NoResize | ImGuiWindowFlags_NoSavedSettings;
            
            // ==========================================
            // SCREEN 1: LOGIN SCREEN (KEYAUTH)
            // ==========================================
            if (!isKeyAuthLogged) {
                ImGui::SetNextWindowSize(ImVec2(350, 200), ImGuiCond_Always);
                ImGui::Begin("LOGIN SYSTEM", &MenDeal, window_flags);
                
                ImGui::Spacing();
                ImGui::TextColored(customAccent, "      COSMOS LOGIN SYSTEM");
                ImGui::Separator();
                ImGui::Spacing(); ImGui::Spacing();
                
                ImGui::Text("Enter License Key:");
                ImGui::InputText("##LicenseField", licenseKeyInput, IM_ARRAYSIZE(licenseKeyInput), ImGuiInputTextFlags_Password);
                
                ImGui::Spacing(); ImGui::Spacing();
                
                if (ImGui::Button("Activate & Login", ImVec2(150, 35))) {
                    std::string keyStr(licenseKeyInput);
                    if (!keyStr.empty()) {
                        // KeyAuth හරහා ලයිසන් එක චෙක් කිරීම
                        KeyAuthApp.license(keyStr); 
                        
                        if (KeyAuthApp.data.success) {
                            isKeyAuthLogged = true;
                            // Expire Date එක සහ ඉතිරි දින ගණන KeyAuth සර්වර් එකෙන් ලබා ගැනීම
                            subExpiryDate = KeyAuthApp.data.expiry;
                            subDaysRemaining = KeyAuthApp.data.ip; // සාමාන්‍යයෙන් API එකේ ඉතිරි දින ගණන හෝ details ලබාගන්නා variable එක
                        } else {
                            // වැරදි Key එකක් නම් reset කිරීම
                            memset(licenseKeyInput, 0, sizeof(licenseKeyInput));
                        }
                    }
                }
                
                ImGui::SameLine();
                if (ImGui::Button("Get Key (TG)", ImVec2(120, 35))) {
                    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"https://t.me/cosmosdemo"] options:@{} completionHandler:nil];
                }
                
                // Login එක Fail වුණොත් Error එක පෙන්වීම
                if (!KeyAuthApp.data.success && !KeyAuthApp.data.message.empty()) {
                    ImGui::Spacing();
                    ImGui::TextColored(ImVec4(1.0f, 0.2f, 0.2f, 1.0f), "Error: %s", KeyAuthApp.data.message.c_str());
                }
                
                ImGui::End();
            } 
            
            // ==========================================
            // SCREEN 2: MAIN MENU (SUCCESSFULLY LOGGED IN)
            // ==========================================
            else {
                ImGui::Begin("COSMOS PRIVATE MENU", &MenDeal, window_flags);
                
                ImGui::Columns(2, "MainLayout", false);
                ImGui::SetColumnWidth(0, 130.0f); 
                
                // LEFT SIDEBAR
                ImGui::PushStyleColor(ImGuiCol_ChildBg, ImVec4(0.03f, 0.04f, 0.06f, 1.00f)); 
                ImGui::BeginChild("Sidebar", ImVec2(0, 0), true);
                
                ImGui::Spacing(); ImGui::Spacing();
                ImGui::TextColored(customAccent, "  COSMOS");
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
                
                // TG Button
                if (ImGui::Button("@cosmos", ImVec2(75, 22))) {
                    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"https://t.me/cosmosdemo"] options:@{} completionHandler:nil];
                }
                
                ImGui::SameLine(ImGui::GetWindowWidth() - 35);
                if (ImGui::Button("X", ImVec2(22, 22))) {
                    MenDeal = false;
                }
                ImGui::Separator();
                ImGui::Spacing();

                // 1. AIMBOT TAB (Image 6)
                if (activeTab == 0) { 
                    ImGui::TextColored(customAccent, "AIMBOT"); 
                    ImGui::SameLine(); ImGui::TextDisabled("| Automatically aim at enemies");
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
                // 2. VISUALS TAB (Image 7)
                else if (activeTab == 1) { 
                    ImGui::TextColored(customAccent, "VISUALS");
                    ImGui::SameLine(); ImGui::TextDisabled("| Various visual improvements");
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
                // 3. MISC TAB (Image 8)
                else if (activeTab == 2) { 
                    ImGui::TextColored(customAccent, "MISC");
                    ImGui::SameLine(); ImGui::TextDisabled("| Game enhancements");
                    ImGui::Spacing();
                    
                    ImGui::Checkbox("No fog", &noFog);
                    ImGui::Checkbox("No FPS limit", &noFpsLimit);
                    ImGui::Checkbox("No weapon spread", &noWeaponSpread);
                } 
                // 4. SETTINGS TAB (Subscription Details)
                else if (activeTab == 3) { 
                    ImGui::TextColored(customAccent, "SETTINGS & SECURITY");
                    ImGui::Spacing();
                    
                    // Accent Color Pick
                    ImGui::Text("Menu Accent Color:");
                    ImGui::SameLine();
                    ImGui::ColorEdit4("##AccentColorPicker", menuAccentColor, ImGuiColorEditFlags_NoInputs);
                    
                    ImGui::Spacing();
                    ImGui::Separator();
                    ImGui::Spacing();
                    
                    // KeyAuth හරහා සර්වර් එකෙන් එන නියම Subscription details ටික මෙතනින් පෙන්වනවා:
                    ImGui::TextColored(customAccent, "SUBSCRIPTION DETAILS");
                    ImGui::Text("User Status: Active VIP");
                    ImGui::Text("License Key: %s", licenseKeyInput);
                    
                    // Expire දිනය පරිවර්තනය කර පෙන්වීම
                    if (subExpiryDate != "N/A") {
                        // KeyAuth සර්වර් එකෙන් එවන UNIX timestamp එක සාමාන්‍ය දිනයකට හරවා පෙන්වීම
                        time_t rawtime = std::stoll(subExpiryDate);
                        struct tm * timeinfo = localtime(&rawtime);
                        char buffer[80];
                        strftime(buffer, sizeof(buffer), "%Y-%m-%d %H:%M:%S", timeinfo);
                        ImGui::Text("Expires: %s", buffer);
                    } else {
                        ImGui::Text("Expires: Lifetime");
                    }
                }
                
                ImGui::EndChild();
                ImGui::Columns(1); 
                ImGui::End();   
            }
        }
        
        ImDrawList* draw_list = ImGui::GetBackgroundDrawList();
        
        // ==========================================
        // CHEAT LOGIC IMPLEMENTATION (Only runs if logged in)
        // ==========================================
        if (isKeyAuthLogged) {
            // Aimbot Hook
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

            // ESP Patch
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

            // FOV Circle
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

- (void)mtkView:(MTKView*)view drawableSizeWillChange:(CGSize)size
{
}

@end
