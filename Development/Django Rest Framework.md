# 🧩 Big Picture Overview

Every DRF request flows through **3 main layers**:

> **View → Serializer → Model**

and each layer calls specific methods depending on HTTP method.

---

# 🧠 1. Core Relationship Map

| HTTP Verb                  | View Method        | Serializer Method                                                | Model Method             | Hook (you can override)      |
| -------------------------- | ------------------ | ---------------------------------------------------------------- | ------------------------ | ---------------------------- |
| **GET (List)**             | `list()`           | `serializer = Serializer(queryset, many=True)`                   | none (read-only)         | `get_queryset()`             |
| **GET (Retrieve)**         | `retrieve()`       | `serializer = Serializer(instance)`                              | none                     | `get_object()`               |
| **POST (Create)**          | `create()`         | `serializer.save()` → calls → `create(validated_data)`           | `Model.objects.create()` | `perform_create(serializer)` |
| **PUT (Update Full)**      | `update()`         | `serializer.save()` → calls → `update(instance, validated_data)` | `instance.save()`        | `perform_update(serializer)` |
| **PATCH (Partial Update)** | `partial_update()` | `serializer.save(partial=True)` → `update()`                     | `instance.save()`        | `perform_update(serializer)` |
| **DELETE**                 | `destroy()`        | none                                                             | `instance.delete()`      | `perform_destroy(instance)`  |

---

# 🧩 2. The Flow (in Code Terms)

Let’s break one down step by step 👇

### 🔹 POST `/api/messages/`

1. DRF calls `create()` in the view
2. Inside it:

   ```python
   serializer = self.get_serializer(data=request.data)
   serializer.is_valid(raise_exception=True)
   self.perform_create(serializer)
   ```
3. Then:

   ```python
   def perform_create(self, serializer):
       serializer.save(sender=self.request.user)
   ```
4. Then in serializer:

   ```python
   def save(self, **kwargs):
       self.validated_data.update(kwargs)
       return self.create(self.validated_data)
   ```
5. Then in `ModelSerializer`:

   ```python
   def create(self, validated_data):
       return Model.objects.create(**validated_data)
   ```

✅ So:
**View.create() → perform_create() → Serializer.save() → Serializer.create() → Model.objects.create()**

---

### 🔹 GET `/api/messages/`

* `list()` → calls `get_queryset()` → returns queryset
* `serializer = Serializer(queryset, many=True)`
* Returns `serializer.data`

**No database write or validation — only serialization.**

---

### 🔹 PUT `/api/messages/1/`

1. DRF calls `update()` in the view
2. Inside it:

   ```python
   serializer = self.get_serializer(instance, data=request.data)
   serializer.is_valid(raise_exception=True)
   self.perform_update(serializer)
   ```
3. Then:

   ```python
   def perform_update(self, serializer):
       serializer.save()
   ```
4. Then inside serializer:

   ```python
   def save(self):
       return self.update(self.instance, self.validated_data)
   ```
5. Then in `ModelSerializer`:

   ```python
   def update(self, instance, validated_data):
       for attr, value in validated_data.items():
           setattr(instance, attr, value)
       instance.save()
       return instance
   ```

✅ So:
**View.update() → perform_update() → Serializer.save() → Serializer.update() → instance.save()**

---

### 🔹 PATCH `/api/messages/1/`

Same as PUT, except:

```python
serializer = Serializer(instance, data=request.data, partial=True)
```

so missing fields aren’t required.

---

### 🔹 DELETE `/api/messages/1/`

1. `destroy()` → calls `get_object()`
2. Then `perform_destroy(instance)`:

   ```python
   def perform_destroy(self, instance):
       instance.delete()
   ```

✅ So:
**View.destroy() → perform_destroy(instance) → instance.delete()**

---

# 🧩 3. DRF View Classes and Their Default Method Mapping

| Class                          | Supported Methods               | Internal Method Mapping                                     |
| ------------------------------ | ------------------------------- | ----------------------------------------------------------- |
| `ListAPIView`                  | `GET`                           | → `list()`                                                  |
| `CreateAPIView`                | `POST`                          | → `create()`                                                |
| `RetrieveAPIView`              | `GET`                           | → `retrieve()`                                              |
| `UpdateAPIView`                | `PUT`, `PATCH`                  | → `update()`, `partial_update()`                            |
| `DestroyAPIView`               | `DELETE`                        | → `destroy()`                                               |
| `ListCreateAPIView`            | `GET`, `POST`                   | → `list()`, `create()`                                      |
| `RetrieveUpdateDestroyAPIView` | `GET`, `PUT`, `PATCH`, `DELETE` | → `retrieve()`, `update()`, `partial_update()`, `destroy()` |
| `ModelViewSet`                 | all CRUD                        | → all above combined automatically                          |

---

# 🧩 4. Conceptual Diagram

```
HTTP Request
    ↓
View (APIView / Generic / ViewSet)
    ↓
get() / post() / put() / patch() / delete()
    ↓
list() / create() / retrieve() / update() / partial_update() / destroy()
    ↓
perform_* hook
    ↓
Serializer.save()
    ↓
Serializer.create() / Serializer.update()
    ↓
Model.objects.create() / instance.save() / instance.delete()
```

---

# 🧩 5. Summary Cheat Sheet

| You Want To                    | Override / Use             |
| ------------------------------ | -------------------------- |
| Filter what’s visible          | `get_queryset()`           |
| Change lookup behavior         | `get_object()`             |
| Add data before saving         | `perform_create()`         |
| Change how data saves          | `create()` in serializer   |
| Change how updates happen      | `update()` in serializer   |
| Change delete logic            | `perform_destroy()`        |
| Pass custom info to serializer | `get_serializer_context()` |
| Full custom POST logic         | `create()` in view         |
| Fully custom GET logic         | `get()` or `list()`        |

---

✅ **Final Mental Model:**

> * View handles HTTP verbs (`get`, `post`, etc.)
> * Each verb triggers a DRF action (`list`, `create`, `retrieve`, `update`, `destroy`)
> * These actions use `perform_*` hooks → call `serializer.save()`
> * `save()` internally calls `create()` or `update()` depending on context.
