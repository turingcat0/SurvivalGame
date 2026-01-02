using System;
using UnityEngine;
using UnityEngine.Rendering;

[ExecuteAlways]
public class TextureHandler : MonoBehaviour
{
    public string globalName = "_InteractionRT";
    public string globalCenterName = "_InteractionCenterWS";
    public string globalRadiusName = "_InteractionRadius";
    public string globalThicknessName = "_InteractionThickness";
    public string globalTexelSizeName = "_InteractionRT_TexelSize";

    public Camera rtCam;

    public GameObject trackObject;
    public int height = 5;

    void OnEnable()
    {
        if (rtCam == null) rtCam = GetComponent<Camera>();
        RenderPipelineManager.beginCameraRendering += OnBeginCameraRendering;
    }

    void OnDisable()
    {
        RenderPipelineManager.beginCameraRendering -= OnBeginCameraRendering;
    }

    private void LateUpdate()
    {
        transform.position = trackObject.transform.position - new Vector3(0, height, 0);
        transform.rotation = Quaternion.Euler(-90, 0, 0);

        var depthRadius = rtCam.farClipPlane - rtCam.nearClipPlane;
        var center = rtCam.transform.position + rtCam.transform.forward * ((rtCam.nearClipPlane + rtCam.farClipPlane) * 0.5f);
        var radius = rtCam.orthographicSize;

        Shader.SetGlobalVector(globalCenterName, center);
        Shader.SetGlobalFloat(globalRadiusName, radius);
        Shader.SetGlobalFloat(globalThicknessName, depthRadius);

    }

    void OnBeginCameraRendering(ScriptableRenderContext ctx, Camera cam)
    {
        var rt = InteractionCameraFeature.SharedInteractionRT;
        if (rt != null)
            Shader.SetGlobalTexture(InteractionCameraFeature.SharedInteractionTexId, rt);
    }
}
