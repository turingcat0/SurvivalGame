using System;
using UnityEngine;
using UnityEngine.InputSystem;

[RequireComponent(typeof(CharacterController))]
public class ThirdPersonMover : MonoBehaviour
{
    [Header("Input")] public InputActionReference moveRef;

    [Header("Refs")] public Transform viewCamera;
    public Animator animator;

    [Header("Move")] public float walkSpeed = 2.5f;
    public float accel = 0.02f;
    public float decel = 0.05f;
    public float runSpeed = 5.0f;
    public float moveDeadZone = 0.1f;

    public float turnSpeed = 0.08f;

    [Header("Gravity")] public float gravity = -20f;
    public float groundedSnapSpeed = -2f;

    private bool onGround;
    private bool running;

    private Vector3 horizVel;
    private float vertVel;
    private CharacterController cc;

    private int velocityID;

    private void Awake()
    {
        cc = GetComponent<CharacterController>();
    }

    private void OnEnable()
    {
        velocityID = Animator.StringToHash("VelocityY");

        if (moveRef != null)
        {
            moveRef.action.Enable();
        }
    }

    private void OnDisable()
    {
        if (moveRef != null)
        {
            moveRef.action.Disable();
        }
    }

    public void Update()
    {
        var wasd = moveRef.action.ReadValue<Vector2>();
        bool hasInput = wasd.magnitude > moveDeadZone * moveDeadZone;
        if (hasInput)
        {
            wasd = wasd.normalized;
        }

        vertVel += gravity * Time.deltaTime;

        Vector3 wishDir = Vector3.zero;
        if (hasInput)
        {
            var forward = viewCamera.forward;
            var right = viewCamera.right;

            forward.y = 0;
            right.y = 0;
            forward.Normalize();
            right.Normalize();

            wishDir = forward * wasd.y + right * wasd.x;
            if (wishDir.magnitude > 1e-06)
            {
                wishDir.Normalize();
            }
        }
        float rate = hasInput ? accel : decel;
        float targetSpeed = running ?  runSpeed : walkSpeed;

        horizVel = Vector3.MoveTowards(horizVel, targetSpeed * wishDir, Time.deltaTime * rate);

        if (hasInput)
        {
            var rot = Quaternion.LookRotation(wishDir);
            animator.transform.rotation =
                Quaternion.RotateTowards(animator.transform.rotation, rot, turnSpeed * Time.deltaTime);
        }

        var motion = horizVel;
        motion.y = vertVel;
        cc.Move(motion * Time.deltaTime);
    }
}