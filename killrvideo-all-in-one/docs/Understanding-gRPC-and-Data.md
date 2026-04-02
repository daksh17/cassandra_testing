# Understanding .proto, gRPC, and What Gets Stored — In Simple Words

This page explains what **.proto** and **gRPC** are, how the `grpc_push_video.sh` script uses them, and **what data ends up in the database** (and in which tables).

---

## 1. What is a .proto file?

Think of a **.proto file** as a **contract** or **menu** that describes:

- **What operations exist**  
  For example: “Create a user,” “Submit a YouTube video,” “Get latest videos.”
- **What each operation needs as input and what it returns**  
  For example: “To create a user, you must send: user ID, first name, last name, email, password. It returns nothing (just success/failure).”

So **.proto = the list of allowed operations and the shape of the data** for each.  
The backend (KillrVideo Java service) implements these operations. Our script uses the same .proto files so it knows exactly what to send.

**In this repo:**  
The `protos/` folder contains those contracts, e.g.:

- `user_management/user_management_service.proto` — operations for users (CreateUser, GetUserProfile, etc.).
- `video_catalog/video_catalog_service.proto` — operations for videos (SubmitYouTubeVideo, GetLatestVideoPreviews, etc.).
- `common/common_types.proto` — shared things like “UUID” (an ID format).

---

## 2. What is gRPC?

**gRPC** is the **way programs talk to the backend** using that contract.

- The backend **exposes** the operations defined in the .proto (e.g. “CreateUser”, “SubmitYouTubeVideo”).
- A client (our script, the web app, or the Generator) **calls** those operations by name and sends the data in the format the .proto describes.
- The backend runs the right code (e.g. “insert this user into the database”) and may return a result.

So: **.proto = the contract (menu). gRPC = the way we place orders using that menu.**

In our case, the backend listens on **port 50101**. The script uses a tool called **grpcurl** to call the backend over gRPC, and grpcurl uses the .proto files to know how to format the requests.

---

## 3. How does the script use .proto and gRPC?

The script does three main things over gRPC (and then one extra step in the DB):

| Step | What the script does | Which .proto / operation |
|------|----------------------|---------------------------|
| 1 | **Get an existing user** (so we don’t create duplicates) | `video_catalog_service.proto` → **GetLatestVideoPreviews** (read-only; no DB write here from this call). |
| 2 | **Create a user** (only if we didn’t find one in step 1) | `user_management_service.proto` → **CreateUser**. Backend writes into the **users** table. |
| 3 | **Submit a YouTube video** | `video_catalog_service.proto` → **SubmitYouTubeVideo**. Backend writes into **videos**, **user_videos**, and **latest_videos**. |
| 4 | **Make sure the video shows on the UI** | Script may run a direct **CQL INSERT** into **latest_videos** (same data the backend would write), so the “Latest” list always shows this video. |

So: **the script uses .proto to know the operation names and data shapes, and gRPC (via grpcurl) to call CreateUser and SubmitYouTubeVideo. The backend then writes the data into the database.**

---

## 4. What data gets stored in the DB, and in which “column families” (tables)?

In Cassandra/DataStax, a **keyspace** is like a database, and a **table** is like a “column family” (where rows and columns are stored). KillrVideo uses the keyspace **`killrvideo`**. Here’s what the script causes to be stored and where.

### Table: **`users`**

- **When:** When the script calls **CreateUser** (step 2 above).
- **What:** One row per user.
- **Main columns (in simple words):**
  - **userid** — unique ID for the user (UUID).
  - **firstname**, **lastname**, **email**, **password** — what you’d expect.

So: **CreateUser via gRPC → one new row in `killrvideo.users`.**

---

### Table: **`videos`**

- **When:** When the script calls **SubmitYouTubeVideo** (step 3).
- **What:** One row per video (the main catalog of all videos).
- **Main columns (in simple words):**
  - **videoid** — unique ID for this video (UUID).
  - **userid** — who added it (links to `users`).
  - **name** — title (e.g. “My gRPC test video”).
  - **description** — text description.
  - **location** — for YouTube, this is the YouTube video ID (e.g. `dQw4w9WgXcQ`); the full URL is built from it.
  - **location_type** — 0 = YouTube, 1 = upload.
  - **preview_image_location** — URL of the thumbnail image (e.g. YouTube thumbnail URL).
  - **tags** — set of tags (e.g. grpc, demo).
  - **added_date** — when the video was added.

So: **SubmitYouTubeVideo via gRPC → one new row in `killrvideo.videos`.**

---

### Table: **`user_videos`**

- **When:** Same **SubmitYouTubeVideo** call (backend writes to several tables at once).
- **What:** “Videos by user” — so we can list “all videos this user added.”
- **Main columns (in simple words):**
  - **userid** — the user (partition: all videos of this user together).
  - **videoid**, **name**, **preview_image_location**, **added_date** — same idea as in `videos`, but organized by user.

So: **SubmitYouTubeVideo → one new row in `killrvideo.user_videos`** (same user + video).

---

### Table: **`latest_videos`**

- **When:** Again from **SubmitYouTubeVideo** (backend), and optionally from the script’s **CQL INSERT** (step 4) so the video shows on the “Latest” page.
- **What:** “Videos by day” — used to show the **RECENT VIDEOS** list on the UI (by date).
- **Main columns (in simple words):**
  - **yyyymmdd** — the day in “YYYYMMDD” format (e.g. `20250312`). This is the **partition key**: all videos added on that day live in that partition.
  - **added_date**, **videoid**, **userid**, **name**, **preview_image_location** — same kind of info as above, so the UI can show the latest videos with thumbnails and links.

So: **SubmitYouTubeVideo → one new row in `killrvideo.latest_videos`** (for “today” on the backend). The script may **also** insert one row here via CQL so the video is guaranteed to appear under “Latest.”

---

## 5. Short summary

| Concept | In simple words |
|--------|------------------|
| **.proto** | Contract/menu: which operations exist (CreateUser, SubmitYouTubeVideo, etc.) and what data each needs and returns. |
| **gRPC** | The way the script (and other clients) call those operations on the backend (port 50101). |
| **Script + .proto + gRPC** | Script uses .proto so grpcurl can send the right “orders” (CreateUser, SubmitYouTubeVideo) over gRPC; the backend then writes to the DB. |
| **Data in DB** | **users** (one row per user), **videos** (one row per video), **user_videos** (videos grouped by user), **latest_videos** (videos grouped by day for the “Latest” list). All in keyspace **`killrvideo`**. |

If you open DataStax Studio and run `SELECT * FROM killrvideo.videos LIMIT 5` or `SELECT * FROM killrvideo.latest_videos WHERE yyyymmdd = '20250312'`, you’ll see the same data that the script pushed via gRPC (and, for latest_videos, possibly the extra CQL insert).
