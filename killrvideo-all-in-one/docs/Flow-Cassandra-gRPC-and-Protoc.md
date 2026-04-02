# Flow: Cassandra ↔ gRPC Response, and Where Protoc Fits

This doc shows (1) how one row in Cassandra maps to a gRPC response message, (2) the full request/response flow, and (3) where the **protoc** compiler is used.

---

## 1. One example: Cassandra row → proto message → gRPC response

**Table:** `killrvideo.latest_videos`  
**RPC:** `GetLatestVideoPreviews` (response type: `GetLatestVideoPreviewsResponse`)

### Cassandra row (one record in the table)

Columns in the table:

| Column (C* name) | Example value | Type in C* |
|------------------|---------------|------------|
| `yyyymmdd` | `'20260312'` | text (partition key) |
| `added_date` | `2026-03-12 10:30:00.000Z` | timestamp |
| `videoid` | `a1b2c3d4-e5f6-4789-a012-3456789abcde` | uuid |
| `userid` | `5c9df251-68c3-4618-ba20-e3f5bf34b256` | uuid |
| `name` | `'My gRPC test video'` | text |
| `preview_image_location` | `'https://img.youtube.com/vi/dQw4w9WgXcQ/default.jpg'` | text |

So the data is **stored in Cassandra** in this shape.

### Proto definition (how the response is described)

From `protos/video-catalog/video_catalog_service.proto`:

```protobuf
message VideoPreview {
  killrvideo.common.Uuid video_id = 1;
  google.protobuf.Timestamp added_date = 2;
  string name = 3;
  string preview_image_location = 4;
  killrvideo.common.Uuid user_id = 5;
}

message GetLatestVideoPreviewsResponse {
  repeated VideoPreview video_previews = 1;
  string paging_state = 2;
}
```

The backend reads rows from `latest_videos`, maps each row to a **VideoPreview** (Java object from generated code), then builds **GetLatestVideoPreviewsResponse** and serializes it to protobuf. The partition key `yyyymmdd` is not sent in the response; it is only used for querying.

### Same data as gRPC response (JSON, after grpcurl decodes)

When the client (e.g. grpcurl) receives the protobuf response and decodes it to JSON, one row might look like this:

```json
{
  "videoPreviews": [
    {
      "videoId": { "value": "a1b2c3d4-e5f6-4789-a012-3456789abcde" },
      "addedDate": "2026-03-12T10:30:00Z",
      "name": "My gRPC test video",
      "previewImageLocation": "https://img.youtube.com/vi/dQw4w9WgXcQ/default.jpg",
      "userId": { "value": "5c9df251-68c3-4618-ba20-e3f5bf34b256" }
    }
  ],
  "pagingState": ""
}
```

So: **Cassandra row** (yyyymmdd, added_date, videoid, userid, name, preview_image_location) → backend maps to **VideoPreview** (proto message) → sent as **protobuf binary** → **grpcurl decodes to JSON** as above.

---

## 2. Line diagram: full flow and where protoc is used

### Build time (backend project only — not this repo)

```
  .proto files                    protoc compiler                Generated code
  (in killrvideo-java repo,   →   (run when building             (Java in killrvideo-java)
   or from killrvideo-service-      killrvideo-java)                - *Pb2.java (messages)
   protos)                          + gRPC plugin                  - *Grpc.java (stubs)
```

- **This repo (killrvideo-all-in-one) does not call killrvideo-java and does not run protoc.** They are separate repositories. We only have copies of the `.proto` files here so grpcurl can encode/decode; we never run a code generator.
- **protoc** is run **inside the killrvideo-java project** when **that** project is built (e.g. Maven/Gradle in that repo). Whoever builds killrvideo-java (developers or CI) runs protoc there; the output is Java message classes and gRPC stubs that get compiled into the backend JAR. The Docker image we use (e.g. `killrvideo/killrvideo-java:3.0.1`) was built from that project elsewhere and already contains that generated code.
- Input: `.proto` files (same definitions as in this repo’s `protos/`).
- Output: language-specific **generated code** that the backend uses at runtime to **serialize/deserialize** and **handle RPCs**.

### Runtime: request/response flow (script → backend → Cassandra → back)

```
  SCRIPT (bash)                GRPCURL                      BACKEND (Java)                    CASSANDRA (DSE)
  ─────────────                ───────                      ───────────────                    ───────────────

  JSON payload                 Reads .proto                 Receives protobuf bytes            Tables:
  -d '{"video_id":             (no protoc here;             Deserializes with                  - killrvideo.users
     {"value":"..."},             uses .proto                  generated Java classes             (CreateUser)
     ...}'                        at runtime)                  (from protoc at build)           - killrvideo.videos
        │                         │                           │                                  (SubmitYouTubeVideo)
        │  stdin / -d              │  encode JSON              │  Java objects                    - killrvideo.latest_videos
        ▼                          ▼    to protobuf            ▼  e.g. SubmitYouTubeVideoRequest   (SubmitYouTubeVideo
  ┌──────────┐              ┌──────────┐                      ┌──────────┐                      + script CQL insert)
       │                     │          │  protobuf binary      │          │  execute CQL          - killrvideo.user_videos
       │                     │ grpcurl  │ ──────────────────►  │ Backend  │ ──────────────────►  (SubmitYouTubeVideo)
       │                     │          │   (wire)              │          │  INSERT/SELECT
       │                     │          │                      │          │
       │                     │          │  protobuf binary     │          │  read rows
       │                     │          │ ◄──────────────────   │          │ ◄──────────────────
       │                     │  decode  │   (wire)              │  build   │  e.g. LatestVideo
       ▼                     │  to JSON │                      │  response│     → VideoPreview
  (script continues)         └──────────┘                      │  object  │
                               │                               └──────────┘
                               ▼
                        Response (JSON)
                        e.g. {"videoPreviews": [...]}
                        or {}
```

### End-to-end in one picture (including protoc)

```
  BUILD TIME (backend project)
  ────────────────────────────
  .proto files  ──►  protoc + grpc plugin  ──►  Generated Java (messages + stubs)

  RUNTIME
  ───────
  Script (JSON)  ──►  grpcurl (uses .proto, no protoc)  ──►  protobuf binary  ──►  Backend (Java)
                                                                                        │
                                                                                        │ uses generated code
                                                                                        ▼
  Script (see response)  ◄──  grpcurl (decode to JSON)  ◄──  protobuf binary  ◄──  Backend  ◄──►  Cassandra
                                                                                  (read/write)
```

---

## 3. Summary table

| Stage | What happens | Who uses .proto / protoc |
|-------|----------------|---------------------------|
| **Build (backend)** | .proto → **protoc** → Java (or other) generated code | **killrvideo-java** (or other backend repo) runs **protoc** when that project is built. This repo (killrvideo-all-in-one) does not run protoc or call that build. |
| **Script → Backend** | Script sends JSON → grpcurl **encodes to protobuf** using .proto → sends bytes | **grpcurl** uses **.proto files at runtime** (no protoc). |
| **Backend** | Receives protobuf → **deserializes** to Java objects (generated classes) → business logic → **reads/writes Cassandra** | Backend uses **generated code** (from protoc). |
| **Backend → Script** | Backend builds response object → **serializes** to protobuf → sends bytes | Backend uses **generated code**. |
| **grpcurl** | Receives protobuf → **decodes to JSON** using .proto → prints to terminal | **grpcurl** uses **.proto at runtime** (no protoc). |

So: **protoc** runs only when **building the backend project** (e.g. killrvideo-java), not in this repo. **This repo never runs protoc and never invokes killrvideo-java’s build.** We only ship **.proto** files for grpcurl to use **at runtime** to encode/decode. Cassandra stores the data; the backend (running from a pre-built Docker image) uses code that was generated by protoc inside killrvideo-java and sends/receives **protobuf** on the wire.

---

## 4. If you want to run protoc or build killrvideo-java from this repo

You can run **protoc** yourself in this repo, and/or **call killrvideo-java’s build** (which runs protoc as part of Maven).

### Run protoc in this repo (generate code from our `protos/`)

- **Python:** Generates Python stubs into `build/gen/python` (uses Docker or local `grpcio-tools`).
  ```bash
  ./scripts/run_protoc.sh python
  ```
  With local tools: `pip install grpcio-tools && USE_LOCAL_PROTOC=1 ./scripts/run_protoc.sh python`

- **Java:** Requires `protoc` (and optionally `protoc-gen-grpc-java`) on your machine. Generates into `build/gen/java`.
  ```bash
  USE_LOCAL_PROTOC=1 ./scripts/run_protoc.sh java
  ```
  If you don’t have protoc installed, use the next option (build killrvideo-java) instead.

### Call killrvideo-java’s build (clone + Maven; Maven runs protoc)

This clones the **killrvideo-java** repo and runs its Maven build. Maven runs **protoc** as part of the build to generate Java from that project’s .proto setup, then compiles the backend.

```bash
./scripts/build_killrvideo_java.sh
```

Default clone location: `../killrvideo-java` (relative to this repo). Override: `./scripts/build_killrvideo_java.sh /path/to/dir`. Requires **git** and **Maven** (`mvn`).

So: **run protoc here** → `scripts/run_protoc.sh`. **Run protoc by building the backend** → `scripts/build_killrvideo_java.sh`.
