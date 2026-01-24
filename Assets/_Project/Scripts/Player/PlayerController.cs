using System;
using UnityEngine;
using UnityEngine.InputSystem;

[RequireComponent(typeof(CharacterController))]
public class PlayerController : MonoBehaviour
{
    [Header("Input")] public InputActionReference moveRef;
    public InputActionReference runRef;
    public InputActionReference jumpRef;
    public InputActionReference crouchRef;


    [Header("Refs")] public Transform viewCamera;
    public Animator animator;

    [Header("Move")] public float walkSpeed = 2.5f;
    public float runSpeed = 5.0f;
    public float crouchSpeed = 0.3f;
    public float crouchRunSpeed = 0.5f;
    public float accel = 0.02f;
    public float decel = 0.05f;
    public float moveDeadZone = 0.1f;

    public float turnSpeed = 0.08f;

    public float jumpHeight = 1.0f;

    public float crouchHeight = 0.2f;

    [Header("Gravity")] public float gravity = -20f;
    public float groundedSnapSpeed = -2f;

    private bool onGround;
    private bool running;
    private bool crouching;

    private Vector3 horizVel;
    private float vertVel;
    private CharacterController cc;

    private int velocityXid;
    private int velocityYid;
    private int velocityZid;
    private int groundedID;
    private int upRightID;

    private void Awake()
    {
        cc = GetComponent<CharacterController>();
        velocityXid = Animator.StringToHash("VelocityX");
        velocityYid = Animator.StringToHash("VelocityY");
        velocityZid = Animator.StringToHash("VelocityZ");
        groundedID = Animator.StringToHash("Grounded");
        upRightID = Animator.StringToHash("Upright");
    }

    private void OnEnable()
    {
        if (moveRef != null)
        {
            moveRef.action.Enable();
        }

        if (runRef != null)
        {
            runRef.action.Enable();
        }

        if (jumpRef != null)
        {
            jumpRef.action.Enable();
        }

        if (crouchRef != null)
        {
            crouchRef.action.Enable();
        }
    }

    private void OnDisable()
    {
        if (moveRef != null)
        {
            moveRef.action.Disable();
        }

        if (runRef != null)
        {
            runRef.action.Disable();
        }

        if (jumpRef != null)
        {
            jumpRef.action.Disable();
        }

        if (crouchRef != null)
        {
            crouchRef.action.Disable();
        }
    }

    public void Update()
    {
        running = runRef.action.IsPressed();

        var wasd = moveRef.action.ReadValue<Vector2>();
        bool hasInput = wasd.magnitude > moveDeadZone * moveDeadZone;
        if (hasInput)
        {
            wasd = wasd.normalized;
        }

        onGround = cc.isGrounded;

        crouching = crouchRef.action.WasPressedThisFrame() ? !crouching : crouching;

        if (onGround && vertVel < 0f)
        {
            vertVel = groundedSnapSpeed;
        }

        if (onGround && jumpRef.action.IsPressed())
        {
            vertVel = Mathf.Sqrt(2f * jumpHeight * -gravity);
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

        float targetSpeed;

        if (crouching)
        {
            targetSpeed = running ? crouchRunSpeed : crouchSpeed;
        }
        else
        {
            targetSpeed = running ? runSpeed : walkSpeed;
        }

        horizVel = Vector3.MoveTowards(horizVel, targetSpeed * wishDir, Time.deltaTime * rate);

        if (hasInput)
        {
            var rot = Quaternion.LookRotation(wishDir);
            animator.transform.rotation =
                Quaternion.RotateTowards(animator.transform.rotation, rot, turnSpeed * Time.deltaTime);
        }

        var motionWs = horizVel;
        motionWs.y = vertVel;

        var motionLs = animator.transform.InverseTransformDirection(motionWs);

        animator.SetFloat(velocityXid, motionLs.x);
        animator.SetFloat(velocityYid, motionLs.y);
        animator.SetFloat(velocityZid, motionLs.z);
        animator.SetBool(groundedID, onGround);
        animator.SetFloat(upRightID, crouching ? crouchHeight : 1.0f);

        cc.Move(motionWs * Time.deltaTime);
    }
}