module harenae.view.CellRenderer;

import harenae.all;

final class CellRenderer {
private:
    struct UBO { align(1):
        mat4 model = mat4.identity();
        mat4 viewProj;
    }
    struct SceneUBO { static assert(SceneUBO.sizeof%16==0); align(1):
        uint2 worldSize;
        float2 worldOffset;
        float2 scale;
        float2 _p1;
    }
    struct Vertex {
        float2 pos;
        float2 uv;
    }
    @Borrowed VulkanContext context;
    Descriptors descriptors;
    GraphicsPipeline pipeline;
    VkSampler sampler;
    SceneUBO snapshotSceneUBO;
    GPUData!UBO ubo;
    GPUData!SceneUBO sceneUbo;
    GPUData!Vertex vertices;
    GPUData!ushort indices;
    GPUData!uint cellDataBuffer;
    GPUData!float4 cellColourBuffer;
    uint numCells;
public:
    this(VulkanContext context, uint numCells) {
        this.context = context;
        this.numCells = numCells;
        initialise();
    }
    void destroy() {
        if(ubo) ubo.destroy();
        if(sceneUbo) sceneUbo.destroy();
        if(cellDataBuffer) cellDataBuffer.destroy();
        if(cellColourBuffer) cellColourBuffer.destroy();
        if(vertices) vertices.destroy();
        if(indices) indices.destroy();
        if(descriptors) descriptors.destroy();
        if(pipeline) pipeline.destroy();
        if(sampler) context.device.destroySampler(sampler);
    }
    auto camera(Camera2D camera) {
        ubo.write((u) {
            u.viewProj = camera.VP();
        });
        return this;
    }
    auto model(mat4 m) {
        ubo.write((u) {
            u.model = m;
        });
        return this;
    }
    void updateScene(Scene scene) {
        if(scene.worldSize != snapshotSceneUBO.worldSize) {
            snapshotSceneUBO.worldSize = scene.worldSize;
            sceneUbo.write((u) {
                u.worldSize = scene.worldSize;
            });
        }
        if(scene.view.worldOffset != snapshotSceneUBO.worldOffset) {
            snapshotSceneUBO.worldOffset = scene.view.worldOffset;
            sceneUbo.write((u) {
                u.worldOffset = scene.view.worldOffset;
            });
        }
        if(scene.view.scale != snapshotSceneUBO.scale) {
            snapshotSceneUBO.scale = scene.view.scale;
            sceneUbo.write((u) {
                u.scale = scene.view.scale;
            });
        }
    }
    void updateCells(uint[] cells) {
        uint* ptr = cellDataBuffer.map();
        ptr[0..cells.length] = cells[];
        cellDataBuffer.setDirtyRange(0, cells.length.as!uint);
    }
    void beforeRenderPass(Frame frame) {
        ubo.upload(frame.resource.adhocCB);
        sceneUbo.upload(frame.resource.adhocCB);
        cellDataBuffer.upload(frame.resource.adhocCB);
        cellColourBuffer.upload(frame.resource.adhocCB);
        vertices.upload(frame.resource.adhocCB);
        indices.upload(frame.resource.adhocCB);
    }
    void insideRenderPass(Frame frame) {
        auto res = frame.resource;
        auto b = res.adhocCB;

        b.bindPipeline(pipeline);
        b.bindDescriptorSets(
            VK_PIPELINE_BIND_POINT_GRAPHICS,
            pipeline.layout,
            0,          // first set
            [descriptors.getSet(0,0)],
            null        // dynamic offsets
        );
        b.bindVertexBuffers(
            0,                                      // first binding
            [vertices.getDeviceBuffer().handle],    // buffers
            [vertices.getDeviceBuffer().offset]);   // offsets
        b.bindIndexBuffer(
            indices.getDeviceBuffer().handle,
            indices.getDeviceBuffer().offset);

        b.drawIndexed(6, 1, 0,0,0);
    }
private:
    void initialise() {
        createUBO();
        createBuffers();
        createVertices();
        createSamplers();
        createDescriptors();
        createPipeline();
    }
    void createUBO() {
        this.ubo = new GPUData!UBO(context, BufID.UNIFORM, true).initialise();
        this.sceneUbo = new GPUData!SceneUBO(context, BufID.UNIFORM, true).initialise();

        sceneUbo.write((u) {
            u.worldSize = uint2(1,1);
            u.worldOffset = float2(0,0);
            u.scale = float2(1);
        });
        snapshotSceneUBO.worldSize = uint2(1,1);
        snapshotSceneUBO.worldOffset = float2(0,0);
        snapshotSceneUBO.scale = float2(1);
    }
    void createBuffers() {
        this.cellDataBuffer = new GPUData!uint(context, "cell_data".as!BufID, true, numCells)
            .initialise();

        this.cellColourBuffer = new GPUData!float4(context, "cell_data".as!BufID, true, 256*float4.sizeof)
            .initialise();  

        cellDataBuffer.memset(0, cellDataBuffer.count);
        cellColourBuffer.memset(0, cellColourBuffer.count);

        float4* ptr = cellColourBuffer.map();
        ptr[  0] = float4(0,   0,   0,   1); // empty
        ptr[  1] = float4(1,   0.7, 0,   1); // sand
        ptr[  2] = float4(0.7, 0.7, 0.7, 1); // rock

        ptr[100] = float4(0,   0.5, 1,   1); // water
        ptr[  3] = float4(1,   1,   1,   1); // everything else
    }
    void createVertices() {
        //
        // 0----1
        // |\   |
        // | \  |
        // |  \ |
        // |   \|
        // 3----2
        Vertex[] verticesArray = [
            Vertex(vec2(0,0), vec2(0,0)),
            Vertex(vec2(1,0), vec2(1,0)),
            Vertex(vec2(1,1), vec2(1,1)),
            Vertex(vec2(0,1), vec2(0,1)),
        ];
        ushort[] indicesArray = [
            0,1,2,
            2,3,0
        ];

        this.vertices = new GPUData!Vertex(context, BufID.VERTEX, true, verticesArray.length.as!uint)
            .initialise();
        this.indices = new GPUData!ushort(context, BufID.INDEX, true, indicesArray.length.as!uint)
            .initialise();

        this.vertices.write(verticesArray);
        this.indices.write(indicesArray);
    }
    void createSamplers() {
        this.sampler = context.build().sampler((ref VkSamplerCreateInfo info) {
            info.magFilter = VK_FILTER_NEAREST;
            info.minFilter = VK_FILTER_NEAREST;
            info.mipmapMode = VK_SAMPLER_MIPMAP_MODE_NEAREST;
        });
    }
    void createDescriptors() {
        /**
            *  0 -> UBO
            *  1 -> SceneUBO
            *  2 -> cell data
            *  3 -> cell colours
            */
        this.descriptors = new Descriptors(context)
            .createLayout()
                .uniformBuffer(VK_SHADER_STAGE_VERTEX_BIT | VK_SHADER_STAGE_FRAGMENT_BIT)
                .uniformBuffer(VK_SHADER_STAGE_FRAGMENT_BIT)
                .storageBuffer(VK_SHADER_STAGE_FRAGMENT_BIT)
                .storageBuffer(VK_SHADER_STAGE_FRAGMENT_BIT)
                .sets(1)
            .build();

        descriptors.createSetFromLayout(0)
                    .add(ubo)
                    .add(sceneUbo)
                    .add(cellDataBuffer)
                    .add(cellColourBuffer)
                    .write();
    }
    void createPipeline() {
        this.pipeline = new GraphicsPipeline(context)
            .withVertexInputState!Vertex(VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST)
            .withDSLayouts(descriptors.getAllLayouts())
            .withVertexShader(context.shaderCompiler().getModule("cell.vert"))
            .withFragmentShader(context.shaderCompiler().getModule("cell.frag"))
            //.withStdColorBlendState()
            .build();
    }
}