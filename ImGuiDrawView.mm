#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>
#import <Foundation/Foundation.h>
//Imgui library
#import "Esp/CaptainHook.h"
#import "Esp/ImGuiDrawView.h"
#import "IMGUI/imgui.h"
#import "IMGUI/imgui_impl_metal.h"
#import "IMGUI/Honkai.h"
//Patch library
#import "5Toubun/NakanoIchika.h"
#import "5Toubun/NakanoNino.h"
#import "5Toubun/NakanoMiku.h"
#import "5Toubun/NakanoYotsuba.h"
#import "5Toubun/NakanoItsuki.h"
#import "5Toubun/dobby.h"

#define kWidth  [UIScreen mainScreen].bounds.size.width
#define kHeight [UIScreen mainScreen].bounds.size.height
#define kScale [UIScreen mainScreen].scale

// Global static variables (මෙනු එකේ values මතක තියාගන්න)
static bool MenDeal = true;

// UI States
static bool aimbotEnable = false;
static bool silentAim = false;
static bool autoFire = false;
static bool showFovCircle = false;
static float fovValue = 30.0f;
static float speedValue = 0.01f;
static float distanceValue = 10.0f;

static bool espEnable = false;
static bool showLines = false;
static bool showBoxes = false;
static bool showSkeleton = false;

static int selectedBone = 0; // 0: Head, 1: Chest, 2: Randomized
static int selectedPriority = 0;

// Active Cheats State Tracking
static bool show_s0 = false;
static bool show_s0_active = false;
static bool aimbot_active = false;
static bool esp_active = false;

@interface ImGuiDrawView () <MTKViewDelegate>
@property (nonatomic, strong) id <MTLDevice> device;
@property (nonatomic, strong) id <MTLCommandQueue> commandQueue;
@end

@implementation ImGuiDrawView

// ගේම් එකේ logic එකට සම්බන්ධ වෙන pointers
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
    self.view = [[MTKView alloc] initWithFrame:CGRectMake(0, 0, w, h)];
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
        [renderEncoder pushDebugGroup:@"ImGui Premium Menu"];

        ImGui_ImplMetal_NewFrame(renderPassDescriptor);
        ImGui::NewFrame();
        
        // ==========================================
        // APPLY PREMIUM DARK & ORANGE STYLE
        // ==========================================
        ImGuiStyle* style = &ImGui::GetStyle();
        style->WindowRounding = 16.0f;       // Rounded Corners
        style->FrameRounding = 10.0f;        // Premium pill-shaped UI elements
        style->GrabRounding = 10.0f;
        style->PopupRounding = 10.0f;
        style->ChildRounding = 12.0f;
        style->WindowPadding = ImVec2(0, 0); // Padding manually handled
        style->FramePadding = ImVec2(14, 10);
        style->ItemSpacing = ImVec2(12, 12);

        ImVec4* colors = style->Colors;
        // Premium Slate-Dark Blue Theme
        colors[ImGuiCol_WindowBg]               = ImVec4(0.06f, 0.07f, 0.10f, 0.98f);
        colors[ImGuiCol_ChildBg]                = ImVec4(0.09f, 0.11f, 0.15f, 0.60f);
        colors[ImGuiCol_FrameBg]                = ImVec4(0.12f, 0.14f, 0.20f, 1.00f);
        colors[ImGuiCol_FrameBgHovered]         = ImVec4(0.16f, 0.19f, 0.27f, 1.00f);
        colors[ImGuiCol_FrameBgActive]          = ImVec4(0.20f, 0.24f, 0.33f, 1.00f);
        
        // Vibrant Orange accents (පින්තූරයේ පරිදි)
        colors[ImGuiCol_CheckMark]              = ImVec4(0.98f, 0.34f, 0.13f, 1.00f);
        colors[ImGuiCol_SliderGrab]             = ImVec4(0.98f, 0.34f, 0.13f, 1.00f);
        colors[ImGuiCol_SliderGrabActive]       = ImVec4(1.00f, 0.45f, 0.20f, 1.00f);
        colors[ImGuiCol_Button]                 = ImVec4(0.98f, 0.34f, 0.13f, 0.85f);
        colors[ImGuiCol_ButtonHovered]          = ImVec4(1.00f, 0.44f, 0.23f, 1.00f);
        colors[ImGuiCol_ButtonActive]           = ImVec4(0.85f, 0.28f, 0.08f, 1.00f);
        
        colors[ImGuiCol_Text]                   = ImVec4(0.95f, 0.96f, 0.98f, 1.00f);
        colors[ImGuiCol_TextDisabled]           = ImVec4(0.50f, 0.55f, 0.64f, 1.00f);
        colors[ImGuiCol_Border]                 = ImVec4(0.15f, 0.18f, 0.25f, 0.50f);
        
        ImFont* font = ImGui::GetFont();
        font->Scale = 15.f / font->FontSize;
        
        // Menu size setup
        CGFloat menuWidth = 580;
        CGFloat menuHeight = 400;
        CGFloat x = ([UIScreen mainScreen].bounds.size.width - menuWidth) / 2;
        CGFloat y = ([UIScreen mainScreen].bounds.size.height - menuHeight) / 2;
        
        ImGui::SetNextWindowPos(ImVec2(x, y), ImGuiCond_FirstUseEver);
        ImGui::SetNextWindowSize(ImVec2(menuWidth, menuHeight), ImGuiCond_FirstUseEver); 
        
        if (MenDeal == true)
        {     
            // Window flags
            ImGuiWindowFlags window_flags = ImGuiWindowFlags_NoCollapse | ImGuiWindowFlags_NoTitleBar | ImGuiWindowFlags_NoResize | ImGuiWindowFlags_NoSavedSettings;
            ImGui::Begin("COSMOS PREMIUM MENU", &MenDeal, window_flags);
            
            // සයිඩ් බාර් එක සහ කන්ටෙන්ට් එක බෙදා ගැනීමට Columns භාවිතය
            ImGui::Columns(2, "MainLayout", false);
            // Column widths (වම්පස Sidebar එකට 150px ද, දකුණුපසට ඉතිරියද වෙන් කෙරේ)
            ImGui::SetColumnWidth(0, 150.0f); 
            
            // ==========================================
            // LEFT SIDEBAR MENU
            // ==========================================
            ImGui::PushStyleColor(ImGuiCol_ChildBg, ImVec4(0.05f, 0.06f, 0.09f, 1.00f)); // Sidebar Darker background
            ImGui::BeginChild("Sidebar", ImVec2(0, 0), true);
            
            ImGui::Spacing(); ImGui::Spacing();
            ImGui::TextColored(ImVec4(0.98f, 0.34f, 0.13f, 1.00f), "  COSMOS");
            ImGui::Separator();
            ImGui::Spacing();

            static int activeTab = 0; // 0: Aimbot, 1: Visuals, 2: Misc, 3: Settings, 4: Account

            // Custom Sidebar buttons to look premium
            const char* tabs[] = { " Aimbot", " Visuals", " Misc", " Settings", " Account" };
            for (int i = 0; i < 5; i++) {
                bool is_selected = (activeTab == i);
                if (is_selected) {
                    ImGui::PushStyleColor(ImGuiCol_Button, ImVec4(0.98f, 0.34f, 0.13f, 0.15f));
                    ImGui::PushStyleColor(ImGuiCol_ButtonHovered, ImVec4(0.98f, 0.34f, 0.13f, 0.20f));
                    ImGui::PushStyleColor(ImGuiCol_ButtonActive, ImVec4(0.98f, 0.34f, 0.13f, 0.25f));
                    ImGui::PushStyleColor(ImGuiCol_Text, ImVec4(0.98f, 0.34f, 0.13f, 1.00f));
                } else {
                    ImGui::PushStyleColor(ImGuiCol_Button, ImVec4(0, 0, 0, 0));
                    ImGui::PushStyleColor(ImGuiCol_ButtonHovered, ImVec4(1, 1, 1, 0.05f));
                    ImGui::PushStyleColor(ImGuiCol_ButtonActive, ImVec4(1, 1, 1, 0.08f));
                    ImGui::PushStyleColor(ImGuiCol_Text, ImVec4(0.6f, 0.65f, 0.7f, 1.00f));
                }

                if (ImGui::Button(tabs[i], ImVec2(130, 40))) {
                    activeTab = i;
                }
                ImGui::PopStyleColor(4);
                ImGui::Spacing();
            }
            ImGui::EndChild();
            ImGui::PopStyleColor(); // Pop sidebar bg

            // Move to next column (Right side content)
            ImGui::NextColumn();
            
            // ==========================================
            // RIGHT CONTENT AREA
            // ==========================================
            ImGui::BeginChild("ContentArea", ImVec2(0, 0), false);
            
            // Close header bar on top right
            ImGui::Spacing();
            ImGui::TextDisabled("STATUS: ACTIVE"); 
            ImGui::SameLine(ImGui::GetWindowWidth() - 40);
            if (ImGui::Button("X", ImVec2(25, 25))) {
                MenDeal = false;
            }
            ImGui::Separator();
            ImGui::Spacing();

            // Render Content based on Active Tab
            if (activeTab == 0) { // AIMBOT
                ImGui::TextColored(ImVec4(0.98f, 0.34f, 0.13f, 1.00f), "AIMBOT SETTINGS");
                ImGui::Spacing();
                
                ImGui::Checkbox("Aimbot Enable", &aimbotEnable);
                ImGui::Checkbox("Silent Aim", &silentAim);
                ImGui::Checkbox("Auto Fire", &autoFire);
                ImGui::Checkbox("Show FOV Circle", &showFovCircle);
                
                ImGui::Spacing();
                ImGui::Separator();
                ImGui::Spacing();
                
                ImGui::SliderFloat("FOV Size", &fovValue, 10.0f, 360.0f, "%.0f px");
                ImGui::SliderFloat("Smooth Speed", &speedValue, 0.01f, 1.0f, "%.2f");
                ImGui::SliderFloat("Max Distance", &distanceValue, 5.0f, 500.0f, "%.0f m");
                
                ImGui::Spacing();
                // Bone Selection Combo Box
                const char* bones[] = { "Head", "Chest", "Randomized" };
                ImGui::Combo("Target Bone", &selectedBone, bones, IM_ARRAYSIZE(bones));

            } 
            else if (activeTab == 1) { // VISUALS
                ImGui::TextColored(ImVec4(0.98f, 0.34f, 0.13f, 1.00f), "VISUALS (ESP)");
                ImGui::Spacing();
                
                ImGui::Checkbox("ESP Master Switch", &espEnable);
                ImGui::Spacing();
                ImGui::Separator();
                ImGui::Spacing();
                
                ImGui::Checkbox("Show Lines (Snaplines)", &showLines);
                ImGui::Checkbox("Show Boxes (2D Box)", &showBoxes);
                ImGui::Checkbox("Show Skeleton", &showSkeleton);
            } 
            else if (activeTab == 2) { // MISC
                ImGui::TextColored(ImVec4(0.98f, 0.34f, 0.13f, 1.00f), "MISCELLANEOUS CHEATS");
                ImGui::Spacing();
                
                ImGui::Checkbox("Map Hack (Map Cheat)", &show_s0);
            } 
            else if (activeTab == 3) { // SETTINGS
                ImGui::TextColored(ImVec4(0.98f, 0.34f, 0.13f, 1.00f), "MENU SETTINGS");
                ImGui::Spacing();
                
                ImGui::Text("FPS: %.1f FPS", ImGui::GetIO().Framerate);
                ImGui::Text("Menu Resolution: %.0f x %.0f", menuWidth, menuHeight);
                ImGui::Spacing();
                if (ImGui::Button("Reset UI Position", ImVec2(180, 35))) {
                    ImGui::SetWindowPos("COSMOS PREMIUM MENU", ImVec2(x, y));
                }
            } 
            else if (activeTab == 4) { // ACCOUNT
                ImGui::TextColored(ImVec4(0.98f, 0.34f, 0.13f, 1.00f), "USER ACCOUNT");
                ImGui::Spacing();
                
                ImGui::Text("User: VIP Member");
                ImGui::Text("Licence Expire: Lifetime");
                ImGui::Spacing();
                ImGui::Separator();
                ImGui::Spacing();
                ImGui::Text("Developer Support Telegram:");
                ImGui::TextColored(ImVec4(0.0f, 0.7f, 1.0f, 1.0f), "@COSMOSDEMO");
            }
            
            ImGui::EndChild();
            ImGui::Columns(1); // Reset Columns layout
            ImGui::End();   
        }
        
        ImDrawList* draw_list = ImGui::GetBackgroundDrawList();
        
        // ==========================================
        // CHEAT LOGIC PROCESSING
        // ==========================================

        // Map Cheat
        if(show_s0){
            if(show_s0_active == NO){
                vm_unity(ENCRYPTOFFSET("0x517A154"), strtoul(ENCRYPTHEX("0x360080D2"), nullptr, 0));
                vm(ENCRYPTOFFSET("0x10517A154"), strtoul(ENCRYPTHEX("0x360080D2"), nullptr, 0));
            }
            show_s0_active = YES;
        } else {
            if(show_s0_active == YES){
                vm_unity(ENCRYPTOFFSET("0x517A154"), strtoul(ENCRYPTHEX("0xF60302AA"), nullptr, 0));
                vm(ENCRYPTOFFSET("0x10517A154"), strtoul(ENCRYPTHEX("0xF60302AA"), nullptr, 0));
            }
            show_s0_active = NO;
        }

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
        if(espEnable){
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

        // DRAW FOV CIRCLE (Aimbot FOV)
        if (aimbotEnable && showFovCircle) {
            ImVec2 center = ImVec2(io.DisplaySize.x / 2.0f, io.DisplaySize.y / 2.0f);
            draw_list->AddCircle(center, fovValue, ImColor(250, 87, 33, 200), 100, 1.5f);
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
