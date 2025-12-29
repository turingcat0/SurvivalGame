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

    public Camera rtCam;

    public GameObject trackObject;
    public int height = 5;

    void OnEnable()
    {
        if (rtCam == null) rtCam = GetComponent<Camera>();
        RenderPipelineManager.beginCameraRendering += OnEndCameraRendering;
    }

    void OnDisable()
    {
        RenderPipelineManager.beginCameraRendering -= OnEndCameraRendering;
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

    void OnEndCameraRendering(ScriptableRenderContext ctx, Camera cam)
    {
        Shader.SetGlobalTexture(globalName, rtCam.targetTexture);
    }
}
