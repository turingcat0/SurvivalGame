using UnityEngine;
using UnityEngine.InputSystem;

[RequireComponent(typeof(CharacterController))]
public class ThirdPersonMover : MonoBehaviour
{
    [Header("Refs")]
    public Transform cameraTransform;
    public Transform cameraTarget;
    public Animator animator;

    [Header("Move")]
    public float walkSpeed = 2.5f;
    public float runSpeed = 5.0f;
    public float turnSmoothTime = 0.08f;
    public bool faceCameraYaw = true;

    [Header("Gravity")]
    public float gravity = -20f;
    public float groundedSnapSpeed = -2f;

    [Header("Look")]
    public float lookSensitivity = 0.15f;
    public float minPitch = -89f;
    public float maxPitch = 89f;
    public bool invertY;

    [Header("Cursor")]
    public bool lockCursorOnStart = true;
    public bool hideCursorWhenLocked = true;
    public bool allowCursorToggle = false;
    public Key toggleCursorKey = Key.Escape;

    [Header("Animator")]
    public string velocityXParam = "VelocityX";
    public string velocityYParam = "VelocityY";
    public string velocityZParam = "VelocityZ";
    public string groundedParam = "Grounded";
    public float velocityDampTime = 0.12f;

    CharacterController _cc;
    float _turnSmoothVelocity;
    float _verticalSpeed;
    float _yaw;
    float _pitch;
    Transform _viewTransform;
    bool _controlsCameraDirectly;
    Vector3 _cameraOffset;
    int _velocityXId;
    int _velocityYId;
    int _velocityZId;
    int _groundedId;

    void Awake()
    {
        _cc = GetComponent<CharacterController>();
        if (!animator) animator = GetComponentInChildren<Animator>();
        _viewTransform = ResolveViewTransform();
        CacheAnimatorIds();
        InitLookAngles();
        InitCameraOffset();
    }

    void Start()
    {
        SetCursorState(lockCursorOnStart);
    }

    void OnValidate()
    {
        CacheAnimatorIds();
    }

    void Update()
    {
        HandleCursorToggle();
        EnsureCursorLocked();
        UpdateLookInput();

        // --- Input System: WASD ---
        Vector2 move = ReadMoveInput();
        bool run = IsRunHeld();
        float targetSpeed = run ? runSpeed : walkSpeed;

        Vector3 input = new Vector3(move.x, 0, move.y);

        // --- camera-relative move ---
        float baseYaw = _viewTransform ? _viewTransform.eulerAngles.y : transform.eulerAngles.y;
        Vector3 moveDir = Quaternion.Euler(0f, baseYaw, 0f) * input;

        if (faceCameraYaw && _viewTransform)
        {
            float angle = Mathf.SmoothDampAngle(transform.eulerAngles.y, baseYaw, ref _turnSmoothVelocity, turnSmoothTime);
            transform.rotation = Quaternion.Euler(0f, angle, 0f);
        }
        else if (moveDir.sqrMagnitude > 0.001f)
        {
            float targetAngle = Mathf.Atan2(moveDir.x, moveDir.z) * Mathf.Rad2Deg;
            float angle = Mathf.SmoothDampAngle(transform.eulerAngles.y, targetAngle, ref _turnSmoothVelocity, turnSmoothTime);
            transform.rotation = Quaternion.Euler(0f, angle, 0f);
        }

        // --- gravity ---
        if (_cc.isGrounded && _verticalSpeed < 0f) _verticalSpeed = groundedSnapSpeed;
        _verticalSpeed += gravity * Time.deltaTime;

        float inputScale = Mathf.Clamp01(move.magnitude);
        Vector3 planarDir = moveDir.sqrMagnitude > 0.0001f ? moveDir.normalized : Vector3.zero;
        Vector3 velocity = planarDir * targetSpeed * inputScale + Vector3.up * _verticalSpeed;
        _cc.Move(velocity * Time.deltaTime);

        UpdateAnimator();
    }

    void LateUpdate()
    {
        ApplyLookTransform();
    }

    Transform ResolveViewTransform()
    {
        // 1) Explicit target set in inspector.
        if (cameraTarget) return cameraTarget;

        // Prefer an explicit "CameraTarget" child (used by Cinemachine in this scene).
        Transform target = transform.Find("CameraTarget");
        if (target) return target;

        // Fallback to assigned camera transform if provided.
        if (cameraTransform) return cameraTransform;

        return null;
    }

    Vector2 ReadMoveInput()
    {
        Vector2 move = Vector2.zero;
        var kb = Keyboard.current;
        if (kb == null) return move;

        if (kb.aKey.isPressed) move.x -= 1f;
        if (kb.dKey.isPressed) move.x += 1f;
        if (kb.sKey.isPressed) move.y -= 1f;
        if (kb.wKey.isPressed) move.y += 1f;

        return Vector2.ClampMagnitude(move, 1f);
    }

    bool IsRunHeld()
    {
        var kb = Keyboard.current;
        if (kb == null) return false;
        return kb.leftShiftKey.isPressed || kb.rightShiftKey.isPressed;
    }

    void InitLookAngles()
    {
        if (!_viewTransform) return;
        Vector3 euler = _viewTransform.rotation.eulerAngles;
        _yaw = euler.y;
        _pitch = euler.x;
    }

    void InitCameraOffset()
    {
        _controlsCameraDirectly = cameraTransform && _viewTransform == cameraTransform;
        if (!_controlsCameraDirectly || !cameraTransform) return;

        Vector3 toCamera = cameraTransform.position - transform.position;
        _cameraOffset = Quaternion.Inverse(cameraTransform.rotation) * toCamera;
    }

    void UpdateLookInput()
    {
        if (!_viewTransform) return;

        var mouse = Mouse.current;
        if (mouse == null) return;

        Vector2 delta = mouse.delta.ReadValue();

        if (delta.sqrMagnitude < Mathf.Epsilon) return;

        _pitch = ClampPitch(_pitch + delta.y * lookSensitivity * (invertY ? 1f : -1f));
        _yaw += delta.x * lookSensitivity;
        _yaw = NormalizeAngle(_yaw);
    }

    void ApplyLookTransform()
    {
        if (!_viewTransform) return;
        Quaternion lookRotation = Quaternion.Euler(_pitch, _yaw, 0f);
        _viewTransform.rotation = lookRotation;

        if (_controlsCameraDirectly && cameraTransform)
        {
            cameraTransform.rotation = lookRotation;
            cameraTransform.position = transform.position + lookRotation * _cameraOffset;
        }
    }

    void HandleCursorToggle()
    {
        if (!allowCursorToggle) return;
        var kb = Keyboard.current;
        if (kb == null) return;
        if (!kb[toggleCursorKey].wasPressedThisFrame) return;

        bool shouldLock = Cursor.lockState != CursorLockMode.Locked;
        SetCursorState(shouldLock);
    }

    void SetCursorState(bool locked)
    {
        Cursor.lockState = locked ? CursorLockMode.Locked : CursorLockMode.None;
        Cursor.visible = !(locked && hideCursorWhenLocked);
    }

    void EnsureCursorLocked()
    {
        if (!lockCursorOnStart) return;
        if (Cursor.lockState != CursorLockMode.Locked)
        {
            SetCursorState(true);
        }
    }

    void CacheAnimatorIds()
    {
        _velocityXId = Animator.StringToHash(velocityXParam);
        _velocityYId = Animator.StringToHash(velocityYParam);
        _velocityZId = Animator.StringToHash(velocityZParam);
        _groundedId = Animator.StringToHash(groundedParam);
    }

    float ClampPitch(float angle)
    {
        angle = NormalizeAngle(angle);
        return Mathf.Clamp(angle, minPitch, maxPitch);
    }

    float NormalizeAngle(float angle)
    {
        angle %= 360f;
        if (angle > 180f) angle -= 360f;
        return angle;
    }

    void UpdateAnimator()
    {
        if (!animator) return;

        Vector3 worldVelocity = _cc.velocity;
        Vector3 localVelocity = transform.InverseTransformDirection(worldVelocity);

        animator.SetFloat(_velocityXId, localVelocity.x, velocityDampTime, Time.deltaTime);
        animator.SetFloat(_velocityYId, localVelocity.y, velocityDampTime, Time.deltaTime);
        animator.SetFloat(_velocityZId, localVelocity.z, velocityDampTime, Time.deltaTime);
        animator.SetBool(_groundedId, _cc.isGrounded);
    }
}
