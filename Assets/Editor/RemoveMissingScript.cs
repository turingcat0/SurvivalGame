#if UNITY_EDITOR
using System.Collections.Generic;
using System.IO;
using UnityEditor;
using UnityEngine;

public static class RemoveMissingScriptsFromPrefabs
{
    [MenuItem("Tools/Cleanup/Remove Missing Scripts From Selected Prefabs")]
    public static void RemoveFromSelectedPrefabs()
    {
        var paths = new HashSet<string>();

        foreach (var obj in Selection.objects)
        {
            var path = AssetDatabase.GetAssetPath(obj);
            if (string.IsNullOrEmpty(path)) continue;
            if (!path.EndsWith(".prefab")) continue;

            // 确保确实是Prefab资源
            if (AssetDatabase.LoadAssetAtPath<GameObject>(path) != null)
                paths.Add(path);
        }

        if (paths.Count == 0)
        {
            Debug.LogWarning("请在Project窗口选中一个或多个Prefab资产（.prefab）后再执行。");
            return;
        }

        int i = 0;
        int totalRemoved = 0;

        try
        {
            foreach (var path in paths)
            {
                i++;
                EditorUtility.DisplayProgressBar(
                    "Remove Missing Scripts",
                    $"{Path.GetFileName(path)} ({i}/{paths.Count})",
                    (float)i / paths.Count
                );

                // 载入Prefab内容（隔离场景），可用于批处理修改
                var root = PrefabUtility.LoadPrefabContents(path);

                int removedThisPrefab = RemoveMissingRecursively(root);

                if (removedThisPrefab > 0)
                {
                    PrefabUtility.SaveAsPrefabAsset(root, path);
                    totalRemoved += removedThisPrefab;
                    Debug.Log($"Removed {removedThisPrefab} missing scripts from: {path}");
                }

                PrefabUtility.UnloadPrefabContents(root);
            }
        }
        finally
        {
            EditorUtility.ClearProgressBar();
            AssetDatabase.SaveAssets();
            Debug.Log($"Done. Total removed missing scripts: {totalRemoved}");
        }
    }

    private static int RemoveMissingRecursively(GameObject go)
    {
        int removed = GameObjectUtility.RemoveMonoBehavioursWithMissingScript(go);

        foreach (Transform child in go.transform)
            removed += RemoveMissingRecursively(child.gameObject);

        return removed;
    }
}
#endif
