import ApplicationController from "mensa/controllers/application_controller";
import { patch, post, destroy } from "@rails/request.js";

export default class ViewsComponentController extends ApplicationController {
    static targets = ["trigger", "triggerLabel", "dropdown", "view", "submenu", "renameDialog", "renameInput", "renameViewId"];
    static outlets = ["mensa-filter-pill-list"];
    static values = {
        tableId: String,
        viewsUrl: String,
    };

    connect() {
        this._activeSubmenuViewId = null;
        this._outsideClickHandler = null;
    }

    disconnect() {
        this._unbindOutsideClick();
    }

    toggleDropdown(event) {
        event.stopPropagation();
        const isOpen = !this.dropdownTarget.classList.contains("hidden");
        if (isOpen) {
            this._closeDropdown();
        } else {
            this._openDropdown();
        }
    }

    select(event) {
        event.preventDefault();
        event.stopPropagation();

        const selected = event.currentTarget;
        const viewId = selected.dataset.viewId || "";

        this.viewTargets.forEach((el) => {
            const btn = el.querySelector("[data-action='mensa-views#select']");
            const check = el.querySelector(".mensa-table__views__option-check");
            const isThis = el.dataset.viewId === viewId;
            check?.classList.toggle("invisible", !isThis);
        });

        const viewName = event.currentTarget.querySelector("span")?.textContent?.trim() || "";
        if (this.hasTriggerLabelTarget) {
            this.triggerLabelTarget.textContent = viewName;
        }

        this._closeDropdown();

        if (this.hasMensaFilterPillListOutlet) {
            this.mensaFilterPillListOutlet.viewSelected(viewId);
        }
    }

    toggleSubmenu(event) {
        event.preventDefault();
        event.stopPropagation();

        const viewId = event.currentTarget.dataset.viewId;
        const optionEl = event.currentTarget.closest("[data-mensa-views-target='view']");

        if (this._activeSubmenuViewId === viewId && !this.submenuTarget.classList.contains("hidden")) {
            this._closeSubmenu();
            return;
        }

        this._activeSubmenuViewId = viewId;
        this.submenuTarget.dataset.viewId = viewId;

        // Position the submenu next to the clicked button
        const rect = event.currentTarget.getBoundingClientRect();
        const dropdownRect = this.dropdownTarget.getBoundingClientRect();
        this.submenuTarget.style.top = `${rect.top - dropdownRect.top}px`;
        this.submenuTarget.style.left = `${dropdownRect.width}px`;

        this.submenuTarget.classList.remove("hidden");
    }

    renameView(event) {
        event.preventDefault();
        const viewId = this.submenuTarget.dataset.viewId;
        const viewEl = this.viewTargets.find((el) => el.dataset.viewId === viewId);
        const viewName = viewEl?.dataset.viewName || "";

        this._closeSubmenu();
        this._closeDropdown();

        if (this.hasRenameDialogTarget) {
            this.renameViewIdTarget.value = viewId;
            this.renameInputTarget.value = viewName;
            if (typeof this.renameDialogTarget.showModal === "function") {
                this.renameDialogTarget.showModal();
            } else {
                this.renameDialogTarget.setAttribute("open", "");
            }
            this.renameInputTarget.select();
        }
    }

    cancelRename(event) {
        if (event) event.preventDefault();
        this._closeRenameDialog();
    }

    renameDialogBackdrop(event) {
        if (event.target === this.renameDialogTarget) {
            this._closeRenameDialog();
        }
    }

    async confirmRename(event) {
        event.preventDefault();
        const viewId = this.renameViewIdTarget.value;
        const newName = this.renameInputTarget.value.trim();
        if (!newName) {
            this.renameInputTarget.reportValidity();
            return;
        }

        const turboFrameId = this._turboFrameId();
        const response = await patch(`${this.viewsUrlValue}/${viewId}`, {
            body: JSON.stringify({ name: newName, turbo_frame_id: turboFrameId }),
            contentType: "application/json",
            responseKind: "turbo-stream",
        });

        if (response.ok) {
            this._closeRenameDialog();
        }
    }

    async duplicateView(event) {
        event.preventDefault();
        const viewId = this.submenuTarget.dataset.viewId;
        const viewEl = this.viewTargets.find((el) => el.dataset.viewId === viewId);
        const viewName = viewEl?.dataset.viewName || "";

        this._closeSubmenu();
        this._closeDropdown();

        // Read the current state from the filter pill list outlet
        let state = { filters: {}, query: "", order: {} };
        if (this.hasMensaFilterPillListOutlet) {
            const outlet = this.mensaFilterPillListOutlet;
            state = {
                filters: outlet.collectFilters(),
                query: outlet.loadQuery(),
                order: outlet.loadOrder(),
                column_order: outlet.loadColumnOrder(),
                hidden_columns: outlet.loadHiddenColumns(),
            };
        }

        const turboFrameId = this._turboFrameId();
        await post(this.viewsUrlValue, {
            body: JSON.stringify({
                name: `${viewName} (copy)`,
                ...state,
                turbo_frame_id: turboFrameId,
            }),
            contentType: "application/json",
            responseKind: "turbo-stream",
        });
    }

    async deleteView(event) {
        event.preventDefault();
        const viewId = this.submenuTarget.dataset.viewId;
        const viewEl = this.viewTargets.find((el) => el.dataset.viewId === viewId);
        const viewName = viewEl?.dataset.viewName || "this view";

        this._closeSubmenu();
        this._closeDropdown();

        if (!confirm(`Delete "${viewName}"?`)) return;

        const turboFrameId = this._turboFrameId();
        await destroy(`${this.viewsUrlValue}/${viewId}`, {
            body: JSON.stringify({ turbo_frame_id: turboFrameId }),
            contentType: "application/json",
            responseKind: "turbo-stream",
        });
    }

    // Called from outside (e.g. after a view is saved/updated) to update the trigger label
    updateSelectedView(viewId, viewName) {
        this.viewTargets.forEach((el) => {
            const check = el.querySelector(".mensa-table__views__option-check");
            check?.classList.toggle("invisible", el.dataset.viewId !== viewId);
        });
        if (this.hasTriggerLabelTarget && viewName) {
            this.triggerLabelTarget.textContent = viewName;
        }
    }

    // --- private ---

    _openDropdown() {
        this.dropdownTarget.classList.remove("hidden");
        this._bindOutsideClick();
    }

    _closeDropdown() {
        this.dropdownTarget.classList.add("hidden");
        this._closeSubmenu();
        this._unbindOutsideClick();
    }

    _closeSubmenu() {
        this.submenuTarget.classList.add("hidden");
        this._activeSubmenuViewId = null;
    }

    _closeRenameDialog() {
        if (!this.hasRenameDialogTarget) return;
        if (typeof this.renameDialogTarget.close === "function") {
            this.renameDialogTarget.close();
        } else {
            this.renameDialogTarget.removeAttribute("open");
        }
    }

    _turboFrameId() {
        const root = this.element.closest(".mensa-table");
        const frame = root?.querySelector("turbo-frame");
        return frame?.id || this.tableIdValue || "";
    }

    _bindOutsideClick() {
        this._unbindOutsideClick();
        this._outsideClickHandler = (e) => {
            if (!this.element.contains(e.target)) {
                this._closeDropdown();
            }
        };
        setTimeout(() => document.addEventListener("click", this._outsideClickHandler), 0);
    }

    _unbindOutsideClick() {
        if (this._outsideClickHandler) {
            document.removeEventListener("click", this._outsideClickHandler);
            this._outsideClickHandler = null;
        }
    }
}
