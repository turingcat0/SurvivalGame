using UnityEngine;

public class MeshProxyHandler : MonoBehaviour
{
    private static readonly int Speed = Shader.PropertyToID("_Speed");
    private Renderer proxyRenderer;
    private Vector3 lastPosition;

    private MaterialPropertyBlock materialPropertyBlock;

    void Start()
    {
        proxyRenderer = GetComponent<Renderer>();
        materialPropertyBlock = new MaterialPropertyBlock();
        lastPosition = transform.position;
    }

    void LateUpdate()
    {
        var speed = (transform.position - lastPosition);
        lastPosition = transform.position;

        var xzSpeed = new Vector2(speed.x, speed.z);
        xzSpeed.Normalize();

        proxyRenderer.GetPropertyBlock(materialPropertyBlock);
        materialPropertyBlock.SetVector(Speed, xzSpeed);
        proxyRenderer.SetPropertyBlock(materialPropertyBlock);
    }
}