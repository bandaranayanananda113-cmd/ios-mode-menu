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

@interface ImGuiDrawView () <MTKViewDelegate>
@property (nonatomic, strong) id <MTLDevice> device;
@property (nonatomic, strong) id <MTLCommandQueue> commandQueue;
@end

@implementation ImGuiDrawView

void (*huy)(void *instance);
void _huy(void *instance)
{
    huy(instance);
}

static bool MenDeal = true;

- (instancetype)initWithNibName:(nullable NSString *)nibNameOrNil bundle:(nullable NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    _device = MTLCreateSystemDefaultDevice();
    _commandQueue = [_device newCommandQueue];

    if (!self.device) abort();
    IMGUI_CHECKVERSION();
    ImGui::CreateContext();
    ImGuiIO& io = ImGui::GetIO(); (void)io;
    
    // මෙතන තමයි Font එක ලෝඩ් කරන්නේ (ඔයාට ඕනෙ නම් පස්සේ වෙනස් කරගන්න පුළුවන්)
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
    
    // UI Bools
    static bool show_s0 = false;    
    static bool aimbotEnable = false;
    static float fovValue = 30.0f;
    static bool espEnable = false;
    static bool showBoxes = false;
    static bool showLines = false;

    static bool show_s0_active = false;
    static bool aimbot_active = false;
    static bool esp_active = false;
        
    [self.view setUserInteractionEnabled:(MenDeal ? YES : NO)];

        MTLRenderPassDescriptor* renderPassDescriptor = view.currentRenderPassDescriptor;
        if (renderPassDescriptor != nil)
        {
            id <MTLRenderCommandEncoder> renderEncoder = [commandBuffer renderCommandEncoderWithDescriptor:renderPassDescriptor];
            [renderEncoder pushDebugGroup:@"ImGui Jane"];

            ImGui_ImplMetal_NewFrame(renderPassDescriptor);
            ImGui::NewFrame();
            
            // ==========================================
            // APPLY PREMIUM STYLE (DARK & ORANGE THEME)
            // ==========================================
            ImGuiStyle* style = &ImGui::GetStyle();
            style->WindowRounding = 12.0f;       // රවුම් කොන්
            style->FrameRounding = 8.0f;         // Checkbox/Sliders රවුම් කිරීම
            style->GrabRounding = 8.0f;
            style->PopupRounding = 8.0f;
            style->TabRounding = 8.0f;
            style->WindowPadding = ImVec2(15, 15);
            style->FramePadding = ImVec2(10, 8);
            style->ItemSpacing = ImVec2(10, 12);
            style->WindowTitleAlign = ImVec2(0.5f, 0.5f); // Title එක මැදට

            ImVec4* colors = style->Colors;
            // Dark Backgrounds
            colors[ImGuiCol_WindowBg]               = ImVec4(0.09f, 0.09f, 0.11f, 1.00f);
            colors[ImGuiCol_TitleBg]                = ImVec4(0.09f, 0.09f, 0.11f, 1.00f);
            colors[ImGuiCol_TitleBgActive]          = ImVec4(0.09f, 0.09f, 0.11f, 1.00f);
            colors[ImGuiCol_FrameBg]                = ImVec4(0.16f, 0.16f, 0.18f, 1.00f);
            colors[ImGuiCol_FrameBgHovered]         = ImVec4(0.20f, 0.20f, 0.22f, 1.00f);
            colors[ImGuiCol_FrameBgActive]          = ImVec4(0.24f, 0.24f, 0.26f, 1.00f);
            // Orange Accents (ඔයාගේ පින්තූර වල තියෙන පාට)
            colors[ImGuiCol_CheckMark]              = ImVec4(1.00f, 0.35f, 0.05f, 1.00f);
            colors[ImGuiCol_SliderGrab]             = ImVec4(1.00f, 0.35f, 0.05f, 1.00f);
            colors[ImGuiCol_SliderGrabActive]       = ImVec4(1.00f, 0.45f, 0.05f, 1.00f);
            colors[ImGuiCol_Button]                 = ImVec4(1.00f, 0.35f, 0.05f, 0.80f);
            colors[ImGuiCol_ButtonHovered]          = ImVec4(1.00f, 0.45f, 0.05f, 1.00f);
            colors[ImGuiCol_ButtonActive]           = ImVec4(1.00f, 0.55f, 0.05f, 1.00f);
            colors[ImGuiCol_Tab]                    = ImVec4(0.16f, 0.16f, 0.18f, 1.00f);
            colors[ImGuiCol_TabHovered]             = ImVec4(1.00f, 0.35f, 0.05f, 0.80f);
            colors[ImGuiCol_TabActive]              = ImVec4(1.00f, 0.35f, 0.05f, 1.00f);
            colors[ImGuiCol_Header]                 = ImVec4(1.00f, 0.35f, 0.05f, 0.80f);
            colors[ImGuiCol_HeaderHovered]          = ImVec4(1.00f, 0.45f, 0.05f, 1.00f);
            colors[ImGuiCol_HeaderActive]           = ImVec4(1.00f, 0.55f, 0.05f, 1.00f);
            colors[ImGuiCol_Text]                   = ImVec4(0.95f, 0.95f, 0.95f, 1.00f);
            colors[ImGuiCol_Separator]              = ImVec4(0.24f, 0.24f, 0.26f, 1.00f);
            // ==========================================
            
            ImFont* font = ImGui::GetFont();
            font->Scale = 15.f / font->FontSize;
            
            CGFloat x = (([UIApplication sharedApplication].windows[0].rootViewController.view.frame.size.width) - 450) / 2;
            CGFloat y = (([UIApplication sharedApplication].windows[0].rootViewController.view.frame.size.height) - 350) / 2;
            
            ImGui::SetNextWindowPos(ImVec2(x, y), ImGuiCond_FirstUseEver);
            ImGui::SetNextWindowSize(ImVec2(450, 350), ImGuiCond_FirstUseEver); 
            
            if (MenDeal == true)
            {     
                // Window Flags - Resize කිරීම නවත්වන්න
                ImGui::Begin("COSMOSDEMO PREMIUM", &MenDeal, ImGuiWindowFlags_NoCollapse | ImGuiWindowFlags_NoSavedSettings);
                
                if (ImGui::BeginTabBar("MenuTabs")) {
                    
                    if (ImGui::BeginTabItem("  Aimbot  ")) {
                        ImGui::Spacing();
                        ImGui::Checkbox("Aimbot Enable", &aimbotEnable);
                        ImGui::Checkbox("Map Cheat", &show_s0);
                        
                        ImGui::Spacing();
                        ImGui::Separator();
                        ImGui::Spacing();
                        
                        ImGui::Text("Aimbot Settings");
                        ImGui::SliderFloat("FOV Circle", &fovValue, 0.0f, 360.0f, "%.1f");
                        ImGui::EndTabItem();
                    }
                    
                    if (ImGui::BeginTabItem("  Visuals  ")) {
                        ImGui::Spacing();
                        ImGui::Checkbox("ESP Enable", &espEnable);
                        ImGui::Spacing();
                        ImGui::Separator();
                        ImGui::Spacing();
                        ImGui::Checkbox("Show Lines", &showLines);
                        ImGui::Checkbox("Show Boxes", &showBoxes);
                        ImGui::EndTabItem();
                    }
                    
                    if (ImGui::BeginTabItem("  Settings  ")) {
                        ImGui::Spacing();
                        ImGui::TextColored(ImVec4(1.0f, 0.35f, 0.05f, 1.0f), "Subscription Info:");
                        ImGui::Text("User: VIP Member");
                        ImGui::Text("Status: Active");
                        ImGui::Spacing();
                        ImGui::Separator();
                        ImGui::Spacing();
                        ImGui::Text("Contact me on Telegram: @COSMOSDEMO");
                        ImGui::Text("FPS: %.1f", ImGui::GetIO().Framerate);
                        ImGui::EndTabItem();
                    }

                    ImGui::EndTabBar();
                }
                ImGui::End();   
            }
            
        ImDrawList* draw_list = ImGui::GetBackgroundDrawList();
        
//START MAIN CHEAT CODE HERE -----------------------------------------------------

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

    if(aimbotEnable){
        if(aimbot_active == NO){
            // Offsets here
        }
        aimbot_active = YES;
    } else {
        if(aimbot_active == YES){
            // Offsets here
        }
        aimbot_active = NO;
    }

    if(espEnable){
        if(esp_active == NO){
            // Offsets here
        }
        esp_active = YES;
    } else {
        if(esp_active == YES){
            // Offsets here
        }
        esp_active = NO;
    }
        
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
          DobbyHook((void *)(getRealOffset(ENCRYPTOFFSET("0x5F145F8"))), (void *)_huy, (void **)&huy);
    });

//END CHEAT LOGIC -----------------------------------------------------

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