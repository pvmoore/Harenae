module harenae.Harenae;

import harenae.all;


final class Harenae : VulkanApplication {
private:
    enum {
        WIDTH               = 1400,
        HEIGHT              = 1000,
        NUM_FRAME_BUFFERS   = 3,
        TITLE               = "Harenae " ~ VERSION
    }
    @Borrowed VkDevice device;
    Vulkan vk;
    VulkanContext context;
    VkRenderPass renderPass;
    uint2 windowSize;
    uint numFrameBuffers;
    Scene scene;
    SceneRenderer sceneRenderer;
public:
    void initialise() {

        WindowProperties wprops = {
            width:        WIDTH,
            height:       HEIGHT,
            fullscreen:   false,
            vsync:        false,
            title:        TITLE,
            icon:         "/pvmoore/_assets/icons/3dshapes.png",
            showWindow:   false,
            frameBuffers: NUM_FRAME_BUFFERS
        };
        VulkanProperties vprops = {
            appName: "Crepitus Harenae",
            apiVersion: vulkanVersion(1,1,0),
            imgui: {
                enabled: true,
                configFlags:
                    ImGuiConfigFlags_NoMouseCursorChange |
                    ImGuiConfigFlags_DockingEnable |
                    ImGuiConfigFlags_ViewportsEnable,
                fontPaths: [
                    "/pvmoore/_assets/fonts/Roboto-Regular.ttf",
                    "/pvmoore/_assets/fonts/RobotoCondensed-Regular.ttf"
                ],
                fontSizes: [
                    22,
                    20
                ]
            }
        };

		this.vk = new Vulkan(this, wprops, vprops);

        // Will call deviceReady
        vk.initialise();

        string gpuName = cast(string)vk.properties.deviceName.ptr.fromStringz;
        vk.setWindowTitle("%s :: Vulkan (%sx%s) :: %s, %s".format(TITLE, WIDTH, HEIGHT, processor().strip(), gpuName));

        vk.showWindow();
    }
    @Implements("IVulkanApplication")
    override void destroy() {
        if(device) {
	        vkDeviceWaitIdle(device);
        }

	    if(device) {
            if(sceneRenderer) sceneRenderer.destroy();
            if(context) context.dumpMemory();
	        if(renderPass) device.destroyRenderPass(renderPass);
            if(context) context.destroy();
	    }
        if(vk) {
            vk.destroy();
            vk = null;
        }
    }
    @Implements("IVulkanApplication")
    override void run() {
        vk.mainLoop();
    }
    @Implements("IVulkanApplication")
    override void deviceReady(VkDevice device, PerFrameResource[] frameResources) {
        this.log("deviceReady");
        this.device = device;
        this.windowSize = vk.windowSize;
        this.numFrameBuffers = vk.swapchain.numImages();

        createContext();
        createScene();
    }
    @Implements("IVulkanApplication")
    override VkRenderPass getRenderPass(VkDevice device) {
        createRenderPass(device);
        return renderPass;
    }
    void update(Frame frame) {
        if(scene.update(frame.seconds, frame.perSecond)) {
            sceneRenderer.update(scene.getCells());
        }
    }
    @Implements("IVulkanApplication")
    override void render(Frame frame) {

        update(frame);

        auto res = frame.resource;
        auto b = res.adhocCB;
        b.beginOneTimeSubmit();

        sceneRenderer.beforeRenderPass(frame);

        // Inside render pass: initialLayout = VImageLayout.UNDEFINED
        b.beginRenderPass(
            context.renderPass,
            res.frameBuffer,
            toVkRect2D(0,0, vk.windowSize.toVkExtent2D),
            [ clearColour(0.5f,0,0,1) ],
            VK_SUBPASS_CONTENTS_INLINE
        );

        sceneRenderer.insideRenderPass(frame);

        b.endRenderPass();
        // After render pass: finalLayout = VImageLayout.PRESENT_SRC_KHR

        b.end();

        /// Submit our render buffer
        vk.getGraphicsQueue().submit(
            [b],
            [res.imageAvailable],
            [VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT],
            [res.renderFinished],  // signal semaphores
            res.fence              // fence
        );
    }
private:
    void createContext() {
        this.log("Creating context");
        auto mem = new MemoryAllocator(vk);

        auto storageSize = (windowSize*numFrameBuffers).hmul();
        this.log("Storage size = %s", storageSize);


        auto maxSceneSize = 1200 * 1200;

        auto cellDataSize = maxSceneSize*4 + 256*float4.sizeof + 65536;

        this.context = new VulkanContext(vk)
            .withMemory(MemID.LOCAL, mem.allocStdDeviceLocal("Harenae_Local", storageSize + 256.MB))
            .withMemory(MemID.STAGING, mem.allocStdStagingUpload("Harenae_Staging", storageSize + 256.MB));

        context.withBuffer(MemID.LOCAL, BufID.VERTEX, VK_BUFFER_USAGE_VERTEX_BUFFER_BIT | VK_BUFFER_USAGE_TRANSFER_DST_BIT, 16.MB)
               .withBuffer(MemID.LOCAL, BufID.INDEX, VK_BUFFER_USAGE_INDEX_BUFFER_BIT | VK_BUFFER_USAGE_TRANSFER_DST_BIT, 16.MB)
               .withBuffer(MemID.LOCAL, BufID.UNIFORM, VK_BUFFER_USAGE_UNIFORM_BUFFER_BIT | VK_BUFFER_USAGE_TRANSFER_DST_BIT, 1.MB)
               .withBuffer(MemID.LOCAL, BufID.STORAGE, VK_BUFFER_USAGE_STORAGE_BUFFER_BIT | VK_BUFFER_USAGE_TRANSFER_DST_BIT, storageSize)
               .withBuffer(MemID.LOCAL, "cell_data".as!BufID, VK_BUFFER_USAGE_STORAGE_BUFFER_BIT | VK_BUFFER_USAGE_TRANSFER_DST_BIT, cellDataSize)
               .withBuffer(MemID.STAGING, BufID.STAGING, VK_BUFFER_USAGE_TRANSFER_SRC_BIT, storageSize + 256.MB);

        context.withRenderPass(renderPass)
               .withFonts("resources/fonts/")
               .withImages("resources/images")
               .withShaderCompiler("src/harenae/shaders/", "resources/shaders/");

        this.log("%s", context);
    }
    void createRenderPass(VkDevice device) {
        this.log("Creating render pass");

        // Create render pass without clearing the back buffer
        // auto colorAttachment = attachmentDescription(
        //     vk.swapchain.colorFormat,
        //     (info) {
        //         info.loadOp = VAttachmentLoadOp.DONT_CARE;
        //     });

        // Create standard render pass
        auto colorAttachment    = attachmentDescription(vk.swapchain.colorFormat);

        auto colorAttachmentRef = attachmentReference(0);

        auto subpass = subpassDescription((info) {
            info.colorAttachmentCount = 1;
            info.pColorAttachments    = &colorAttachmentRef;
        });

        this.renderPass = .createRenderPass(
            device,
            [colorAttachment],
            [subpass],
            subpassDependency2()
        );
    }
    void createScene() {
        this.scene = new Scene(context);
        this.sceneRenderer = new SceneRenderer(context, scene);
    }
}