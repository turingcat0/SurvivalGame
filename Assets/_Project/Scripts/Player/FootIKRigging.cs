using UnityEngine;

[RequireComponent(typeof(Animator))]
public class FootIKRigging : MonoBehaviour
{
    [Header("Ground")]
    public LayerMask groundMask;
    public float castUp = 0.25f;
    public float castDown = 1.2f;
    public float sphereRadius = 0.06f;

    [Header("Foot Placement")]
    public float footOffsetY = 0.02f;      // 脚底离地面留一点缝（世界Y方向）
    public float maxFootAdjust = 0.25f;     // 脚最多抬/压多少（避免极端地形拉断腿）

    [Header("Smoothing")]
    public float posSmoothTime = 0.08f;    // 单位秒，0.05~0.15常用
    public float rotSpeed = 18f;           // 10~25常用

    Animator anim;
    int lWId, rWId;

    Vector3 lVel, rVel;
    Vector3 lIkPos, rIkPos;
    Quaternion lIkRot, rIkRot;

    void Awake()
    {
        anim = GetComponent<Animator>();
        lWId = Animator.StringToHash("LeftIKWeight");
        rWId = Animator.StringToHash("RightIKWeight");

        lIkPos = Vector3.zero;
        rIkPos = Vector3.zero;
        lIkRot = Quaternion.identity;
        rIkRot = Quaternion.identity;
    }

    void OnAnimatorIK(int layerIndex)
    {
        float lw = anim.GetFloat(lWId);
        float rw = anim.GetFloat(rWId);

        SolveFoot(AvatarIKGoal.LeftFoot, lw, ref lIkPos, ref lIkRot, ref lVel);
        SolveFoot(AvatarIKGoal.RightFoot, rw, ref rIkPos, ref rIkRot, ref rVel);
    }

    void SolveFoot(AvatarIKGoal goal, float w, ref Vector3 ikPos, ref Quaternion ikRot, ref Vector3 smoothVel)
    {
        anim.SetIKPositionWeight(goal, w);
        anim.SetIKRotationWeight(goal, w);

        if (w <= 0.001f) return;

        Vector3 footPos = anim.GetIKPosition(goal);
        Quaternion footRot = anim.GetIKRotation(goal);

        Vector3 origin = footPos + Vector3.up * castUp;
        float dist = castUp + castDown;

        if (Physics.SphereCast(origin, sphereRadius, Vector3.down, out RaycastHit hit,
            dist, groundMask, QueryTriggerInteraction.Ignore))
        {
            Vector3 desiredPos = hit.point + Vector3.up * footOffsetY;

            float dy = desiredPos.y - footPos.y;
            dy = Mathf.Clamp(dy, -maxFootAdjust, maxFootAdjust);
            desiredPos.y = footPos.y + dy;

            ikPos = Vector3.SmoothDamp(ikPos == Vector3.zero ? footPos : ikPos,
                                       desiredPos, ref smoothVel, posSmoothTime);

            Vector3 fwd = Vector3.ProjectOnPlane(transform.forward, hit.normal);
            if (fwd.sqrMagnitude < 1e-6f) fwd = Vector3.ProjectOnPlane(transform.right, hit.normal);

            Quaternion desiredRot = Quaternion.LookRotation(fwd.normalized, hit.normal);
            float t = 1f - Mathf.Exp(-rotSpeed * Time.deltaTime);
            ikRot = Quaternion.Slerp(ikRot == Quaternion.identity ? footRot : ikRot, desiredRot, t);

            anim.SetIKPosition(goal, ikPos);
            anim.SetIKRotation(goal, ikRot);
        }
    }
}
