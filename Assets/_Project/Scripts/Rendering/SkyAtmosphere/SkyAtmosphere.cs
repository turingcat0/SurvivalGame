using System;
using UnityEngine;

namespace TuringCat.Rendering.SkyAtomshpere
{
    public class SkyAtmosphere : MonoBehaviour
    {
        void Update()
        {
            DynamicGI.UpdateEnvironment();
        }
    }
}