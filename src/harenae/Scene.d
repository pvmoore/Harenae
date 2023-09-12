module harenae.Scene;

import harenae.all;

/**
 *  Cell:
 *      float type
 *      vec2 pos
 *      vec2 velocity
 *
 *  ComputeShader:
 *      Run 1 shader per 8x8 block. Assumes no cell will move more than 4 pixels in a single step.
 *
 *      For each cell that is not air:
 *          Move the content by velocity and update pos.
 *          Move to destination cell if necessary/possible.
 *
 *      BankA: Storage cell data (1 Cell per pixel)
 *      BankB: Storage cell data (1 Cell per pixel)
 *      CurrentBank id (A or B)
 *
 *      Update Bank A or B (opposite of read bank)
 *      Write resulting targetImage.
 *
 *      X....... ........ X....... ........
 *      ........ ........ ........ ........
 *      ........ ........ ........ ........
 *      ........ ........ ........ ........
 *      ........ ........ ........ ........
 *      ........ ........ ........ ........
 *      ........ ........ ........ ........
 *      ........ ........ ........ ........
 *
 *      X....... ........ X....... ........
 *
 *  Fragment Shader:
 *      Render targetImage
 *
 */
final class Scene {
public:
    static struct View {
        float2 worldOffset;
        float2 scale;
        float2 aspectRatio;
        Camera2D camera;
    }
    // Static scene data
    uint2 worldSize;
    
    // Dynamic scene data
    View view;

    this(VulkanContext context) {
        this.context = context;
        this.worldSize = uint2(1200, 1200);

        auto windowSize = context.vk.windowSize.to!float;
        auto aspectRatio = windowSize / windowSize.y;

        this.view = View(float2(360,120), aspectRatio*0.3, aspectRatio, Camera2D.forVulkan(windowSize));
        this.cells.length = worldSize.hmul();
        this.cellUpdater = new CellUpdater(worldSize);

        this.log("Created Scene of %s x %s (%s cells)", worldSize.width, worldSize.height, worldSize.hmul());
    }

    int2 windowPosToCellPos(float2 windowPos) {
        float2 size = float2(1000, 1000) * view.scale;
        float2 uv = windowPos / context.vk.windowSize.to!float;
        return (view.worldOffset + uv*size).to!int;
    }

    uint[] getCells() {
        return cells;
    }

    /** 
     * Return true if any cells have changed
     */
    bool update(float seconds, float perSecond) {
        if(seconds > lastUpdateTime + UPDATE_FREQUENCY) {
            lastUpdateTime = seconds;
            tick();
            return true;
        }
        return false;
    }
private:
    enum UPDATE_FREQUENCY = 1/60.0f; // 60 times per second
    @Borrowed VulkanContext context;  
    CellUpdater cellUpdater;
    float lastUpdateTime = 0;  
    uint[] cells;


    /** 
     * Update all cells. 
     * Called every UPDATE_FREQUENCY seconds.
     */
    void tick() {
        cellUpdater.update(cells);
    }
}