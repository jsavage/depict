# The Life of a Diagram: From Text to Pixels

This narrative follows the data flow of a model description pasted into a web browser, processed by the Rust backend, and finally rendered as a diagram.

### Phase 1: The Request (Browser to Server)
The user pastes a model description into a `<textarea>` on the `index.html` page and clicks a "Render" button.

* **Responsibility:** **Frontend JavaScript (inside `WEBROOT`)**
* **Action:** The JavaScript grabs the text from the `textarea` and sends it as a `POST` request to the `/api/draw/v1` endpoint in a JSON format.


### Phase 2: Receiving the Request
The web server receives the HTTP request and routes it to the appropriate handler.

* **Responsibility:** **`main()` function in the Axum code**
* **Action:** The `.route("/api/draw/v1", post(draw))` line tells the server to pass this request to the `draw` function. The code also sets up `tracing_subscriber` to log this request for debugging.


### Phase 3: Parsing and Internal Representation
The server takes the raw text and turns it into a structured internal representation.

* **Responsibility:** **`draw` function and `depict::graph_drawing::frontend::dom::draw`**
* **Action:** The server uses `tokio::task::spawn_blocking` to ensure this CPU-intensive task does not block the web server from handling other users.
* **Responsibility:** **`graph_drawing.rs` (The Brain)**
* **Action:** The parser (referenced in the `graph_drawing` docs) breaks down the text based on its grammar, identifying **Processes**, **Chains**, and **Styles**. It converts these into the `Val` enum tree, which is a logical map of the user's intent.

### Phase 4: Layout and Mathematical Optimization
The engine calculates the physical layout of the nodes and lines, optimizing for readability (minimizing line crossings).

* **Responsibility:** **`graph_drawing.rs` (layout module)**
* **Action:**
    1.  **Ranking:** The engine uses Floyd-Warshall to establish vertical "ranks" (rows) for the nodes.
    2.  **Horizontal Placement:** It uses a "generate-and-test" solver to arrange nodes horizontally within rows to minimize edge crossings.
    3.  **Hops:** Edges that span multiple rows are broken into "hops" to align with the grid-based layout.


### Phase 5: Geometry Solving
Now that relative positions are known, exact coordinates ($x, y$) are calculated.

* **Responsibility:** **`graph_drawing.rs` (geometry module)**
* **Action:**
    1.  **Constraints:** The layout is translated into mathematical constraints (e.g., "Node B must be $x$ pixels below Node A").
    2.  **Solver:** The engine passes these constraints to the **OSQP** numerical solver to determine optimal precise coordinates and Bézier curve paths for connecting lines.


### Phase 6: Mapping and Response
The complex, mathematically calculated representation is simplified into a format the browser can easily draw.

* **Responsibility:** **`draw` function in the Axum code**
* **Action:** The raw `depict` library output is converted into a `depict::rest::Drawing` object, mapping internal complex nodes into simpler `Node::Div` (for boxes) and `Node::Svg` (for lines).
* **Action:** This is wrapped in a `DrawResp` JSON object and sent back to the browser.

### Phase 7: Rendering
The browser receives the instructions and draws the pixels.

* **Responsibility:** **Frontend JavaScript (inside `WEBROOT`)**
* **Action:** The JavaScript receives the JSON. It loops through the nodes and lines, dynamically creating HTML elements (`<div>` for nodes, `<svg>` for lines) and applying CSS styles (like `position: absolute`) based on the coordinates provided by the server.
