using System;
using UnityEngine;

namespace TuringCat.Rendering.SkyAtomshpere
{
    [ExecuteAlways]
    public class SkyAtmosphere : MonoBehaviour
    {
        public float fogScale = 10.0f;
        private static readonly int fogScaleProperty = Shader.PropertyToID("_FogScale");


        void Update()
        {
            DynamicGI.UpdateEnvironment();
            Shader.SetGlobalFloat(fogScaleProperty, fogScale);
        }
    }
}