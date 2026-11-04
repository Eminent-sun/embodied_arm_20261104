#include "urdf_kinematics.h"

#include <float.h>
#include <math.h>
#include <string.h>

#define IK_MAX_ITERATIONS       (180U)
#define IK_SEED_COUNT           (8U)
#define IK_DAMPING              (0.025f)
#define IK_MAX_STEP_RAD         (0.12f)
#define IK_POSITION_TOL_M       (0.0005f)
#define IK_ORIENTATION_TOL_RAD  (0.00873f)

static const float g_origin_xyz[6][3] =
{
    {0.0f,      0.0f,        0.0f},
    {0.0f,      0.0f,        0.0875f},
    {0.24245f, -0.0018586f,  -0.000525f},
    {0.067234f, 0.14958f,    -0.00032776f},
    {0.0f,      0.0f,        0.0f},
    {0.0f,      0.0f,        0.0f},
};

static const float g_origin_rpy[6][3] =
{
    {0.0f,    0.0f,     0.0f},
    {1.5708f, 0.0f,     3.1416f},
    {0.0f,    0.0f,     1.5645f},
    {1.6024f, 1.5708f, -3.1037f},
    {0.0f,    1.5708f,  0.0f},
    {3.1416f,-1.5708f,  0.0f},
};

static const float g_joint_min[6] = {-3.140000f, 0.395710f, -3.027351f, -3.140000f, -1.545172f, -3.140000f};
static const float g_joint_max[6] = { 3.140000f, 3.223736f,  0.074481f,  3.140000f,  1.570000f,  3.140000f};
static const float g_home[6]      = {0.0f, 1.57f, 0.0f, 0.0f, 1.57f, 0.0f};

static void mat_identity (float r[3][3])
{
    memset(r, 0, sizeof(float) * 9U);
    r[0][0] = 1.0f; r[1][1] = 1.0f; r[2][2] = 1.0f;
}

static void mat_mul (const float a[3][3], const float b[3][3], float out[3][3])
{
    float t[3][3];
    for (unsigned i = 0U; i < 3U; i++)
    {
        for (unsigned j = 0U; j < 3U; j++)
        {
            t[i][j] = 0.0f;
            for (unsigned k = 0U; k < 3U; k++) { t[i][j] += a[i][k] * b[k][j]; }
        }
    }
    memcpy(out, t, sizeof(t));
}

static void mat_vec (const float r[3][3], const float v[3], float out[3])
{
    for (unsigned i = 0U; i < 3U; i++) { out[i] = r[i][0] * v[0] + r[i][1] * v[1] + r[i][2] * v[2]; }
}

static void rotation_rpy (const float rpy[3], float r[3][3])
{
    float cr = cosf(rpy[0]); float sr = sinf(rpy[0]);
    float cp = cosf(rpy[1]); float sp = sinf(rpy[1]);
    float cy = cosf(rpy[2]); float sy = sinf(rpy[2]);
    r[0][0] = cy * cp; r[0][1] = cy * sp * sr - sy * cr; r[0][2] = cy * sp * cr + sy * sr;
    r[1][0] = sy * cp; r[1][1] = sy * sp * sr + cy * cr; r[1][2] = sy * sp * cr - cy * sr;
    r[2][0] = -sp;    r[2][1] = cp * sr;                r[2][2] = cp * cr;
}

static void rotation_z (float angle, float r[3][3])
{
    float c = cosf(angle); float s = sinf(angle);
    mat_identity(r);
    r[0][0] = c; r[0][1] = -s; r[1][0] = s; r[1][1] = c;
}

static void forward_with_jacobian (const float q[6], urdf_pose_t * pose, float jacobian[6][6])
{
    float r[3][3];
    float p[3] = {0.0f, 0.0f, 0.0f};
    float axis[6][3];
    float origin[6][3];
    mat_identity(r);

    for (unsigned joint = 0U; joint < 6U; joint++)
    {
        float translated[3]; float ro[3][3]; float rz[3][3];
        mat_vec(r, g_origin_xyz[joint], translated);
        for (unsigned k = 0U; k < 3U; k++) { p[k] += translated[k]; origin[joint][k] = p[k]; }
        rotation_rpy(g_origin_rpy[joint], ro);
        mat_mul(r, ro, r);
        axis[joint][0] = r[0][2]; axis[joint][1] = r[1][2]; axis[joint][2] = r[2][2];
        rotation_z(q[joint], rz);
        mat_mul(r, rz, r);
    }

    memcpy(pose->rotation, r, sizeof(pose->rotation));
    memcpy(pose->position, p, sizeof(pose->position));
    if (NULL == jacobian) { return; }

    for (unsigned j = 0U; j < 6U; j++)
    {
        float d[3] = {p[0] - origin[j][0], p[1] - origin[j][1], p[2] - origin[j][2]};
        jacobian[0][j] = axis[j][1] * d[2] - axis[j][2] * d[1];
        jacobian[1][j] = axis[j][2] * d[0] - axis[j][0] * d[2];
        jacobian[2][j] = axis[j][0] * d[1] - axis[j][1] * d[0];
        jacobian[3][j] = axis[j][0]; jacobian[4][j] = axis[j][1]; jacobian[5][j] = axis[j][2];
    }
}

void urdf_kinematics_forward (const float joint_rad[6], urdf_pose_t * pose)
{
    if ((NULL != joint_rad) && (NULL != pose)) { forward_with_jacobian(joint_rad, pose, NULL); }
}

static float vector_norm (const float * v, unsigned count)
{
    float sum = 0.0f;
    for (unsigned i = 0U; i < count; i++) { sum += v[i] * v[i]; }
    return sqrtf(sum);
}

static void orientation_error (const float current[3][3], const float target[3][3], float error[3])
{
    float re[3][3];
    for (unsigned i = 0U; i < 3U; i++)
    {
        for (unsigned j = 0U; j < 3U; j++)
        {
            re[i][j] = target[i][0] * current[j][0] + target[i][1] * current[j][1] + target[i][2] * current[j][2];
        }
    }
    float cos_angle = 0.5f * (re[0][0] + re[1][1] + re[2][2] - 1.0f);
    if (cos_angle > 1.0f) { cos_angle = 1.0f; }
    if (cos_angle < -1.0f) { cos_angle = -1.0f; }
    float angle = acosf(cos_angle);
    float skew[3] = {re[2][1] - re[1][2], re[0][2] - re[2][0], re[1][0] - re[0][1]};
    float skew_norm = vector_norm(skew, 3U);
    if (skew_norm > 1.0e-6f)
    {
        for (unsigned i = 0U; i < 3U; i++) { error[i] = skew[i] * angle / skew_norm; }
    }
    else
    {
        error[0] = error[1] = error[2] = 0.0f;
    }
}

static bool solve_6x6 (float a[6][6], float b[6], float x[6])
{
    for (unsigned col = 0U; col < 6U; col++)
    {
        unsigned pivot = col;
        for (unsigned row = col + 1U; row < 6U; row++)
        {
            if (fabsf(a[row][col]) > fabsf(a[pivot][col])) { pivot = row; }
        }
        if (fabsf(a[pivot][col]) < 1.0e-9f) { return false; }
        if (pivot != col)
        {
            for (unsigned k = col; k < 6U; k++) { float t = a[col][k]; a[col][k] = a[pivot][k]; a[pivot][k] = t; }
            float t = b[col]; b[col] = b[pivot]; b[pivot] = t;
        }
        float divisor = a[col][col];
        for (unsigned k = col; k < 6U; k++) { a[col][k] /= divisor; }
        b[col] /= divisor;
        for (unsigned row = 0U; row < 6U; row++)
        {
            if (row == col) { continue; }
            float factor = a[row][col];
            for (unsigned k = col; k < 6U; k++) { a[row][k] -= factor * a[col][k]; }
            b[row] -= factor * b[col];
        }
    }
    memcpy(x, b, sizeof(float) * 6U);
    return true;
}

static void make_seed (unsigned index, const float current[6], float seed[6])
{
    static const float variations[8][6] =
    {
        {0, 0, 0, 0, 0, 0}, {1.2f, 0, -0.8f, 0, -0.7f, 0}, {-1.2f, 0, -0.8f, 0, -0.7f, 0},
        {0.8f, 0.4f, -1.5f, -0.5f, -0.6f, 0}, {-0.8f, 0.4f, -1.5f, 0.5f, -0.6f, 0},
        {1.8f, 0.1f, -2.0f, -1.0f, -1.2f, -1.0f}, {-1.8f, 0.1f, -2.0f, 1.0f, -1.2f, 1.0f},
        {0.0f, 0.8f, -2.5f, 0.0f, -1.0f, 0.0f},
    };
    for (unsigned i = 0U; i < 6U; i++)
    {
        seed[i] = ((0U == index) ? current[i] : g_home[i]) + variations[index][i];
        if (seed[i] < g_joint_min[i]) { seed[i] = g_joint_min[i]; }
        if (seed[i] > g_joint_max[i]) { seed[i] = g_joint_max[i]; }
    }
}

bool urdf_kinematics_inverse (const urdf_pose_t * target, const float current[6], urdf_ik_result_t * result)
{
    if ((NULL == target) || (NULL == current) || (NULL == result)) { return false; }
    float best_cost = FLT_MAX;
    bool found = false;

    for (unsigned seed_index = 0U; seed_index < IK_SEED_COUNT; seed_index++)
    {
        float q[6];
        make_seed(seed_index, current, q);
        for (unsigned iteration = 0U; iteration < IK_MAX_ITERATIONS; iteration++)
        {
            urdf_pose_t pose; float j[6][6]; float e[6];
            forward_with_jacobian(q, &pose, j);
            for (unsigned i = 0U; i < 3U; i++) { e[i] = target->position[i] - pose.position[i]; }
            orientation_error(pose.rotation, target->rotation, &e[3]);
            float position_error = vector_norm(e, 3U);
            float orientation_error_value = vector_norm(&e[3], 3U);
            if ((position_error <= IK_POSITION_TOL_M) && (orientation_error_value <= IK_ORIENTATION_TOL_RAD))
            {
                float cost = 5.0f * position_error + orientation_error_value;
                for (unsigned i = 0U; i < 6U; i++) { cost += 0.01f * fabsf(q[i] - current[i]); }
                if (cost < best_cost)
                {
                    best_cost = cost; found = true;
                    memcpy(result->joint_rad, q, sizeof(q));
                    result->position_error_m = position_error;
                    result->orientation_error_rad = orientation_error_value;
                    result->iterations = iteration + 1U;
                }
                break;
            }

            float a[6][6] = {{0}}; float b[6] = {0}; float delta[6];
            for (unsigned row = 0U; row < 6U; row++)
            {
                for (unsigned col = 0U; col < 6U; col++)
                {
                    for (unsigned k = 0U; k < 6U; k++) { a[row][col] += j[k][row] * j[k][col]; }
                }
                a[row][row] += IK_DAMPING * IK_DAMPING;
                for (unsigned k = 0U; k < 6U; k++) { b[row] += j[k][row] * e[k]; }
            }
            if (!solve_6x6(a, b, delta)) { break; }
            for (unsigned i = 0U; i < 6U; i++)
            {
                if (delta[i] > IK_MAX_STEP_RAD) { delta[i] = IK_MAX_STEP_RAD; }
                if (delta[i] < -IK_MAX_STEP_RAD) { delta[i] = -IK_MAX_STEP_RAD; }
                q[i] += delta[i];
                if (q[i] < g_joint_min[i]) { q[i] = g_joint_min[i]; }
                if (q[i] > g_joint_max[i]) { q[i] = g_joint_max[i]; }
            }
        }
    }
    return found;
}
