using UnityEngine;
using UnityEngine.Rendering;

[ExecuteAlways]
public class TextureHandler : MonoBehaviour
{
    public string globalName = "_InteractionRT";
    public Camera rtCam;

    void OnEnable()
    {
        if (rtCam == null) rtCam = GetComponent<Camera>();
        RenderPipelineManager.beginCameraRendering += OnBeginCameraRendering;
    }

    void OnDisable()
    {
        RenderPipelineManager.beginCameraRendering -= OnBeginCameraRendering;
    }

    void OnBeginCameraRendering(ScriptableRenderContext ctx, Camera cam)
    {
        Shader.SetGlobalTexture(globalName, rtCam.targetTexture);
    }
}
