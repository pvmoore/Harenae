module harenae.view.SceneRenderer;

import harenae.all;

final class SceneRenderer {
private:
    @Borrowed VulkanContext context;
    @Borrowed Scene scene;
    CellRenderer cellRenderer;

    uint editType = uint.max;
public:
    this(VulkanContext context, Scene scene) {
        this.context = context;
        this.scene = scene;
        initialise();
    }
    void destroy() {
        if(cellRenderer) cellRenderer.destroy();
    }
    void update(uint[] cells) {
        cellRenderer.updateCells(scene.getCells());
    }
    void beforeRenderPass(Frame frame) {
        bool sceneChanged = false;
        float moveRate = 200*frame.perSecond;
        float zoomRate = 5 * frame.perSecond;
        auto mouse = context.vk.getMouseState();

        if(mouse.wheel > 0) {
            scene.view.scale -= scene.view.aspectRatio*zoomRate;
            sceneChanged = true;
        } else if(mouse.wheel < 0) {
            scene.view.scale += scene.view.aspectRatio*zoomRate;
            sceneChanged = true;
        }

        if(editType!=uint.max) {
            if(context.vk.isMouseButtonPressed(0)) {

                int2 cellPos = scene.windowPosToCellPos(mouse.pos);
                //this.log("clicked cell %s", cellPos);

                scene.getCells()[cellPos.x + cellPos.y*scene.worldSize.x] = editType;
            }
        }

        if(context.vk.isKeyPressed(GLFW_KEY_UP)) {
            scene.view.worldOffset.y -= moveRate;
            sceneChanged = true;
        }
        if(context.vk.isKeyPressed(GLFW_KEY_DOWN)) {
            scene.view.worldOffset.y += moveRate;
            sceneChanged = true;
        }
        if(context.vk.isKeyPressed(GLFW_KEY_LEFT)) {
            scene.view.worldOffset.x -= moveRate;
            sceneChanged = true;
        }
        if(context.vk.isKeyPressed(GLFW_KEY_RIGHT)) {
            scene.view.worldOffset.x += moveRate;
            sceneChanged = true;
        }
        if(sceneChanged) {
            cellRenderer.updateScene(scene);
        }
        cellRenderer.beforeRenderPass(frame);
    }
    void insideRenderPass(Frame frame) {
        cellRenderer.insideRenderPass(frame);
        renderUI(frame);
    }
private:
    void initialise() {
        createCellRenderer();
    }

    void createCellRenderer() {
        this.cellRenderer = new CellRenderer(context, scene.worldSize.hmul());

        auto windowSize = context.vk.windowSize();

        auto scale = mat4.scale(float3(windowSize.width, windowSize.height, 0));
        auto trans = mat4.identity();//mat4.translate(float3(0,0,0));
        cellRenderer.camera(scene.view.camera);
        cellRenderer.model(trans*scale);

        cellRenderer.updateScene(scene);
    }
    void renderUI(Frame frame) {
        context.vk.imguiRenderStart(frame);

        igSetNextWindowPos(ImVec2(8, 8), ImGuiCond_Once, ImVec2(0, 0));

        auto windowFlags = ImGuiWindowFlags_None
            | ImGuiWindowFlags_NoSavedSettings
            //| ImGuiWindowFlags_NoTitleBar
            //| ImGuiWindowFlags_NoCollapse
            | ImGuiWindowFlags_NoResize
            | ImGuiWindowFlags_NoBackground
            //| ImGuiWindowFlags_NoMove;
            ;


        igPushFont(context.vk.getImguiFont(0));
        igPushStyleVar_Float(ImGuiStyleVar_FrameBorderSize, 1);

        if(igBegin("Harenae", null, windowFlags)) {
            uiTabInfo();
            uiTabEdit();
        }
        igEnd();

        igPopStyleVar(1);
        igPopFont();

        context.vk.imguiRenderEnd(frame);
    }
    void uiTabInfo() {
        static bool open = true;

        if(igCollapsingHeader("Info", open ? ImGuiTreeNodeFlags_DefaultOpen : 0)) {

            const flags = ImGuiTableFlags_None
                | ImGuiTableFlags_Borders
                | ImGuiTableFlags_RowBg;

            const numCols = 2;
            const outerSize = ImVec2(200,0);
            const innerWidth = 0f;

            auto leftColour = ImVec4(0, 0.8, 1, 1);
            auto rightColour = ImVec4(0.8, 1, 0, 1);

            void row(string key, string value) {
                igTableNextRow(ImGuiTableRowFlags_None, 10);
                igTableSetColumnIndex(0);
                igTextColored(leftColour, key.toStringz());

                igTableSetColumnIndex(1);
                igTextColored(rightColour, value.toStringz());
            }
            void rowI(string key, int value) {
                row(key, "%s".format(value));
            }
            void rowF(string key, float value) {
                row(key, "%.2f".format(value));
            }

            if(igBeginTable("infoTable", numCols, flags, outerSize, innerWidth)) {

                rowF("FPS", context.vk.getFPSSnapshot());

                rowI("Width", scene.worldSize.x);
                rowI("Height", scene.worldSize.y);

                rowF("Offset X", scene.view.worldOffset.x);
                rowF("Offset Y", scene.view.worldOffset.y);

                row("Scale", "%.2f x %.2f".format(scene.view.scale.x, scene.view.scale.y));

                igEndTable();
            }
        }
    }

    void uiTabEdit() {
        static bool open = true;
        if(igCollapsingHeader("Edit", open ? ImGuiTreeNodeFlags_DefaultOpen : 0)) {

            igPushStyleVar(ImGuiStyleVar_FrameRounding, 4.0);

            auto numStyleColors = 0;
            if(editType == CellType.SAND) {
                //igPushStyleColor_Vec4(ImGuiCol_Button, ImVec4(1,1,0,1));
                //numStyleColors++;
            } 

            //igPushStyleColor_Vec4(ImGuiCol_Button, ImVec4(1,1,0,1));
            //igPushStyleColor_Vec4(ImGuiCol_ButtonActive, ImVec4(1,1,1,1));

            if(igButtonEx("Sand".ptr, ImVec2(60, 30), ImGuiButtonFlags_Repeat)) {
                editType = CellType.SAND;
            }
            //igPopStyleColor(numStyleColors);


            if(igButtonEx("Water".ptr, ImVec2(60, 30), ImGuiButtonFlags_PressedOnClick)) {
                editType = CellType.WATER;
            }


            igText("Selected: ");
            igSameLine(0, 0);
            if(editType == CellType.SAND) {
                igText("Sand");
            }
            if(editType == CellType.WATER) {
                igText("Water");
            }

            igPopStyleVar(1);
        }
    }
}
