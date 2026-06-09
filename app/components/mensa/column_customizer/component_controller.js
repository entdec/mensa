import ApplicationController from "mensa/controllers/application_controller";

export default class ColumnCustomizerController extends ApplicationController {
    static outlets = ["mensa-table"];
    static targets = ["popover", "columnRow"];
    static values = { turboFrameId: String, tableName: String };

    connect() {
        super.connect();
        this._dragSource = null;
        this._dragGhost = null;
        this._outsideClickHandler = null;

        // Capture the server-rendered order before localStorage reorders the DOM.
        this._defaultColumnOrder = this.columnRowTargets.map(
            (r) => r.dataset.columnName,
        );

        // 1. Update the DOM immediately (reorder rows, flip data-visible).
        //    CSS [data-visible] rules handle icon display — no JS icon work needed.
        const hasState = this._applyLocalState();

        // 2. Bake the column params into the mensa-table element's tableUrlValue
        //    right now, before any outlet connects. filter_pill_list.restoreState()
        //    reads ourUrl → tableUrlValue to build the initial frame URL, so by
        //    injecting here we get column_order[] into that single first request
        //    without needing a separate second frame load.
        if (hasState) {
            this._pendingStorageApply = !this._injectColumnParamsIntoTableUrl();
        }
    }

    disconnect() {
        this._unbindOutsideClick();
    }

    // Fallback: only reached when _injectColumnParamsIntoTableUrl couldn't find
    // the mensa-table element during connect() (unusual page structures).
    mensaTableOutletConnected() {
        if (this._pendingStorageApply) {
            this._pendingStorageApply = false;
            this._applyChanges();
        }
    }

    toggle() {
        if (this.popoverTarget.classList.contains("hidden")) {
            this.popoverTarget.classList.remove("hidden");
            this._positionPopover();
            this._bindOutsideClick();
        } else {
            this.popoverTarget.classList.add("hidden");
            this._unbindOutsideClick();
        }
    }

    _positionPopover() {
        const btn = this.element.querySelector("button");
        if (!btn) return;
        const rect = btn.getBoundingClientRect();
        this.popoverTarget.style.top = `${rect.bottom + 4}px`;
        this.popoverTarget.style.right = `${window.innerWidth - rect.right}px`;
        this.popoverTarget.style.left = "auto";
    }

    toggleVisibility(event) {
        event.stopPropagation();
        const row = event.currentTarget.closest("[data-column-name]");
        const nowVisible = row.dataset.visible !== "true";

        // Flip the data-visible attribute — CSS handles which icon is shown.
        row.dataset.visible = nowVisible.toString();

        const nameEl = row.querySelector(
            ".mensa-table__column_customizer__name",
        );
        if (nameEl) {
            nameEl.classList.toggle(
                "mensa-table__column_customizer__name--hidden",
                !nowVisible,
            );
        }

        this._persistAndApply();
    }

    dragStart(event) {
        this._dragSource = event.currentTarget;
        event.dataTransfer.effectAllowed = "move";
        event.dataTransfer.setData("text/plain", ""); // required for Firefox

        // Build a clean ghost so the screenshot doesn't bleed through the
        // popover and show the underlying table row.
        const src = event.currentTarget;
        const ghost = src.cloneNode(true);
        Object.assign(ghost.style, {
            position: "absolute",
            top: "-1000px",
            left: "0",
            width: `${src.offsetWidth}px`,
            background: "white",
            borderRadius: "8px",
            boxShadow: "0 4px 12px rgba(0,0,0,0.15)",
            pointerEvents: "none",
        });
        document.body.appendChild(ghost);
        event.dataTransfer.setDragImage(
            ghost,
            src.offsetWidth / 2,
            src.offsetHeight / 2,
        );
        this._dragGhost = ghost;

        setTimeout(() => this._dragSource?.classList.add("opacity-40"), 0);
    }

    dragOver(event) {
        event.preventDefault();
        event.dataTransfer.dropEffect = "move";
        const target = event.currentTarget;
        if (!this._dragSource || target === this._dragSource) return;
        const rect = target.getBoundingClientRect();
        const midY = rect.top + rect.height / 2;
        if (event.clientY < midY) {
            target.parentNode.insertBefore(this._dragSource, target);
        } else {
            target.parentNode.insertBefore(
                this._dragSource,
                target.nextSibling,
            );
        }
    }

    drop(event) {
        event.preventDefault();
    }

    dragEnd(event) {
        this._dragSource?.classList.remove("opacity-40");
        this._dragSource = null;
        if (this._dragGhost) {
            this._dragGhost.remove();
            this._dragGhost = null;
        }
        this._persistAndApply();
    }

    // Resets the popover DOM to the original server-rendered order and makes all
    // columns visible. Called by the table controller after a view reset.
    resetToDefault() {
        if (this._defaultColumnOrder) {
            this._reorderRows(this._defaultColumnOrder);
        }
        this.columnRowTargets.forEach((row) => {
            row.dataset.visible = "true";
            const nameEl = row.querySelector(
                ".mensa-table__column_customizer__name",
            );
            if (nameEl)
                nameEl.classList.remove(
                    "mensa-table__column_customizer__name--hidden",
                );
        });
    }

    // --- private ---

    _persistAndApply() {
        this._persistToStorage();
        this._applyChanges();
        if (this.hasMensaTableOutlet) {
            this.mensaTableOutlet.notifyUnsavedState();
        }
    }

    _applyChanges() {
        if (!this.hasMensaTableOutlet) return;

        const url = this.mensaTableOutlet.ourUrl;
        this._preserveActiveView(url);

        // Strip stale column customizer params.
        const toDelete = [];
        url.searchParams.forEach((_, key) => {
            if (
                key.startsWith("column_order") ||
                key.startsWith("hidden_columns")
            ) {
                toDelete.push(key);
            }
        });
        toDelete.forEach((k) => url.searchParams.delete(k));

        // Write current order and visibility from the DOM.
        this.columnRowTargets.forEach((row) => {
            url.searchParams.append("column_order[]", row.dataset.columnName);
            if (row.dataset.visible === "false") {
                url.searchParams.append(
                    "hidden_columns[]",
                    row.dataset.columnName,
                );
            }
        });

        // Navigate the frame directly so its src stays in sync with the column
        // params. The column customizer lives outside the frame, so the popover
        // remains open. Subsequent filter/sort requests will inherit the updated
        // src (including column_order[] and hidden_columns[]) via ourUrl.
        const frame = document.getElementById(this.turboFrameIdValue);
        if (frame) frame.setAttribute("src", url.toString());
    }

    // Update localStorage with the current DOM state.
    _persistToStorage() {
        const order = this.columnRowTargets.map((r) => r.dataset.columnName);
        const hidden = this.columnRowTargets
            .filter((r) => r.dataset.visible === "false")
            .map((r) => r.dataset.columnName);

        this._writeStorage(
            this._columnOrderKey,
            order.length ? JSON.stringify(order) : null,
        );
        this._writeStorage(
            this._hiddenColumnsKey,
            hidden.length ? JSON.stringify(hidden) : null,
        );
    }

    // Apply persisted column state to the DOM only (no server call).
    // Called during connect() before outlets are available.
    // Returns true if any state was restored (signals that a server call is needed).
    _applyLocalState() {
        const rawOrder = this._readStorage(this._columnOrderKey);
        const rawHidden = this._readStorage(this._hiddenColumnsKey);
        if (!rawOrder && !rawHidden) return false;

        const order = rawOrder ? JSON.parse(rawOrder) : null;
        const hidden = rawHidden ? JSON.parse(rawHidden) : [];

        if (order) this._reorderRows(order);

        // Flip data-visible on each row. The CSS [data-visible] rules handle
        // showing/hiding the correct eye icon — no querySelector("i") needed.
        this.columnRowTargets.forEach((row) => {
            const isHidden = hidden.includes(row.dataset.columnName);
            row.dataset.visible = (!isHidden).toString();
            const nameEl = row.querySelector(
                ".mensa-table__column_customizer__name",
            );
            if (nameEl) {
                nameEl.classList.toggle(
                    "mensa-table__column_customizer__name--hidden",
                    isHidden,
                );
            }
        });

        return true;
    }

    // Writes column_order[] and hidden_columns[] into the mensa-table element's
    // data-mensa-table-table-url-value attribute so that ourUrl() (used by
    // filter_pill_list.restoreState) carries the column params in the very first
    // frame request. Returns true on success.
    _injectColumnParamsIntoTableUrl() {
        const tableEl = document.getElementById(
            `table-${this.turboFrameIdValue}`,
        );
        if (!tableEl) return false;

        const urlStr = tableEl.dataset.mensaTableTableUrlValue;
        if (!urlStr) return false;

        try {
            const url = new URL(urlStr);

            const toDelete = [];
            url.searchParams.forEach((_, key) => {
                if (
                    key.startsWith("column_order") ||
                    key.startsWith("hidden_columns")
                ) {
                    toDelete.push(key);
                }
            });
            toDelete.forEach((k) => url.searchParams.delete(k));

            this.columnRowTargets.forEach((row) => {
                url.searchParams.append(
                    "column_order[]",
                    row.dataset.columnName,
                );
                if (row.dataset.visible === "false") {
                    url.searchParams.append(
                        "hidden_columns[]",
                        row.dataset.columnName,
                    );
                }
            });

            this._preserveActiveView(url);
            tableEl.dataset.mensaTableTableUrlValue = url.toString();
            return true;
        } catch (e) {
            return false;
        }
    }

    _reorderRows(order) {
        if (!this.hasColumnRowTarget) return;
        const list = this.columnRowTargets[0].parentNode;
        const rowMap = {};
        this.columnRowTargets.forEach((row) => {
            rowMap[row.dataset.columnName] = row;
        });
        order.forEach((name) => {
            if (rowMap[name]) list.appendChild(rowMap[name]);
        });
        // Append any rows not present in the saved order at the end.
        this.columnRowTargets.forEach((row) => {
            if (!order.includes(row.dataset.columnName)) {
                list.appendChild(row);
            }
        });
    }

    _preserveActiveView(url) {
        const view =
            this.mensaTableOutlet?.mensaFilterPillListOutlet?.loadView?.() ||
            "";
        if (view) url.searchParams.set("table_view_id", view);
    }

    get _columnOrderKey() {
        return `mensa:column_order:${this.tableNameValue}`;
    }

    get _hiddenColumnsKey() {
        return `mensa:hidden_columns:${this.tableNameValue}`;
    }

    _writeStorage(key, value) {
        try {
            if (value === null) {
                window.localStorage.removeItem(key);
            } else {
                window.localStorage.setItem(key, value);
            }
        } catch (e) {
            // localStorage unavailable (private mode / disabled) — ignore.
        }
    }

    _readStorage(key) {
        try {
            return window.localStorage.getItem(key);
        } catch (e) {
            return null;
        }
    }

    _bindOutsideClick() {
        this._unbindOutsideClick();
        this._outsideClickHandler = (event) => {
            if (!this.element.contains(event.target)) {
                this.popoverTarget.classList.add("hidden");
                this._unbindOutsideClick();
            }
        };
        // Defer so the opening click doesn't immediately close the popover.
        setTimeout(() => {
            document.addEventListener("click", this._outsideClickHandler);
        }, 0);
    }

    _unbindOutsideClick() {
        if (this._outsideClickHandler) {
            document.removeEventListener("click", this._outsideClickHandler);
            this._outsideClickHandler = null;
        }
    }
}
