using Unity.Cinemachine;
using UnityEngine;
using UnityEngine.InputSystem;

public class MouseVisibilityController : MonoBehaviour
{
    public CinemachineInputAxisController axisController;

    void Start()
    {
        Lock();
    }

    void Update()
    {
        if (Keyboard.current != null && Keyboard.current.escapeKey.wasPressedThisFrame)
            Unlock();

        if (Mouse.current != null && Mouse.current.leftButton.wasPressedThisFrame)
            Lock();
    }

    void Lock()
    {
        Cursor.lockState = CursorLockMode.Locked;
        Cursor.visible = false;
        if (axisController) axisController.enabled = true;
    }

    void Unlock()
    {
        Cursor.lockState = CursorLockMode.None;
        Cursor.visible = true;
        if (axisController) axisController.enabled = false;
    }
}