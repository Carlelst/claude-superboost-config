# Wiki Skill API 文档

## 概述

此文档描述了Wiki技能的API接口和使用方式，该技能通过REST API与Enflame Wiki进行交互。

## 接口列表

### 1. 获取所有空间
- **端点**: `/rest/api/space`
- **方法**: `GET`
- **参数**: 
  - `limit`: 限制返回结果数量
- **描述**: 获取所有Wiki空间信息

### 2. 获取页面
- **端点**: `/rest/api/content/{pageId}` 或 `/rest/api/content`
- **方法**: `GET`
- **参数**: 
  - `pageId`: 页面ID
  - `spaceKey`: 空间键
  - `title`: 页面标题
  - `expand`: 展开字段
- **描述**: 获取单个页面的详细信息

### 3. 搜索页面
- **端点**: `/rest/api/content/search`
- **方法**: `GET`
- **参数**: 
  - `cql`: CQL查询语句
  - `limit`: 限制返回结果数量
- **描述**: 使用CQL查询语言搜索页面

### 4. 获取页面子页面
- **端点**: `/rest/api/content/{pageId}/child/page`
- **方法**: `GET`
- **参数**: 
  - `limit`: 限制返回结果数量
- **描述**: 获取指定页面的子页面

### 5. 获取页面附件
- **端点**: `/rest/api/content/{pageId}/child/attachment`
- **方法**: `GET`
- **描述**: 获取指定页面的附件信息

### 6. 获取页面评论
- **端点**: `/rest/api/content/{pageId}/child/comment`
- **方法**: `GET`
- **参数**: 
  - `limit`: 限制返回结果数量
- **描述**: 获取指定页面的评论信息

## 使用示例

### 基本查询
```bash
curl -X GET "http://wiki.enflame.cn/rest/api/space?limit=10" \
  -u "username:password"
```

### 页面搜索
```bash
curl -X GET "http://wiki.enflame.cn/rest/api/content/search?cql=type%20=%20page%20and%20title%20~%20'技术文档'" \
  -u "username:password"
```

### 创建页面
```bash
curl -X POST "http://wiki.enflame.cn/rest/api/content" \
  -u "username:password" \
  -H "Content-Type: application/json" \
  -d '{
    "type": "page",
    "title": "新页面",
    "space": {"key": "TEST"},
    "body": {
      "storage": {
        "value": "<p>页面内容</p>",
        "representation": "storage"
      }
    }
  }'
```

## 错误码
- `401`: 认证失败
- `403`: 权限不足
- `404`: 资源未找到
- `500`: 服务器内部错误