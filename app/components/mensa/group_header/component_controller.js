import ApplicationController from "mensa/controllers/application_controller";

// Collapses and expands groups in a grouped table. Collapsed groups are
// remembered per table and group column.
export default class GroupsController extends ApplicationController {
    static targets = ["header", "row"];
    static values = { storageKey: String };

    connect() {
        super.connect();
        this.collapsed = new Set(this._load());
        this._apply();
    }

    toggle(event) {
        const key = event.currentTarget.dataset.groupKey;
        if (this.collapsed.has(key)) {
            this.collapsed.delete(key);
        } else {
            this.collapsed.add(key);
        }
        this._save();
        this._apply();
    }

    _apply() {
        this.headerTargets.forEach((header) => {
            header.setAttribute(
                "aria-expanded",
                (!this.collapsed.has(header.dataset.groupKey)).toString(),
            );
        });
        this.rowTargets.forEach((row) => {
            row.classList.toggle(
                "hidden",
                this.collapsed.has(row.dataset.groupKey),
            );
        });
    }

    _load() {
        try {
            return JSON.parse(
                window.localStorage.getItem(this.storageKeyValue) || "[]",
            );
        } catch (e) {
            return [];
        }
    }

    _save() {
        try {
            if (this.collapsed.size > 0) {
                window.localStorage.setItem(
                    this.storageKeyValue,
                    JSON.stringify([...this.collapsed]),
                );
            } else {
                window.localStorage.removeItem(this.storageKeyValue);
            }
        } catch (e) {}
    }
}
