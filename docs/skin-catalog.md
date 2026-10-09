# 服务器皮肤清单格式

在 `Resources/Info.plist` 中添加 `WBSkinCatalogURL`（HTTPS 地址）即可启用服务器皮肤库。未配置时 App 只显示内置渐变皮肤，也不会因为皮肤库发起任何网络请求。

## manifest.json

```json
{
  "version": 1,
  "skins": [
    {
      "id": "3F2A7C1E-8D4B-4E6F-9A1B-2C3D4E5F6A7B",
      "name": "Mount Fuji",
      "subtitle": "富士山下",
      "category": "风景",
      "image": "https://cdn.example.com/skins/mount-fuji.png"
    }
  ]
}
```

| 字段 | 必填 | 说明 |
| --- | --- | --- |
| `id` | 是 | UUID 字符串，发布后不要再改，“已应用”和“收藏”都依赖它；不是 UUID 的条目会被忽略 |
| `name` | 是 | 皮肤名称 |
| `subtitle` | 否 | 副标题 |
| `category` | 否 | 分类名称，皮肤库按它分组；缺省为「在线皮肤」 |
| `image` | 是 | 卡面图片，**必须是 HTTPS**；建议 1536×969 的 PNG |

## 行为

- 每次启动拉取一次清单；拉取成功后缓存到 `~/Library/Application Support/WalletBloom/Catalog/manifest.json`，网络不可用时使用缓存。
- 缩略图通过 `AsyncImage` 加载（遵循 HTTP 缓存头），应用到 iPhone 时才下载原图到临时目录，用完即删。
- 与内置皮肤 id 重复的条目会被忽略。

## 内容规范

- 不使用任何银行、发卡机构或卡组织的标识（与免责声明一致）。
- 确保拥有图片的使用和分发权利。
