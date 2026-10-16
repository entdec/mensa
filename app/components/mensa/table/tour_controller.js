import ApplicationController from "mensa/controllers/application_controller";
import { driver } from "driver.js";

// Explains the table's features the first time each one is seen. Every feature is
// its own segment, remembered in localStorage, so a feature missing on one table is
// still explained the first time it shows up on another.
const SEGMENTS = [
    { key: "search", selector: "[data-mensa-tour='search']" },
    { key: "columns", selector: "[data-mensa-tour='columns']" },
    { key: "sorting", selector: "th a.order" },
    { key: "group_by", selector: "[data-mensa-tour='group_by']" },
    { key: "views", selector: "[data-mensa-tour='views']" },
    { key: "export", selector: "[data-mensa-tour='export']" },
];

const STORAGE_PREFIX = "mensa:tour:seen:";

export default class TourController extends ApplicationController {
    static values = { texts: Object };

    connect() {
        super.connect();
        this._started = false;
        this._hovered = false;
        this._onFrameLoad = () => this._schedule();
        this._onEnter = () => (this._hovered = true);
        this._onLeave = () => (this._hovered = false);
        this._onKeydown = (event) => {
            if (event.key !== "?" || !this._hovered) return;
            if (event.target.closest?.("input, textarea, select, [contenteditable]")) return;
            event.preventDefault();
            this._start(true);
        };
        this.element.addEventListener("turbo:frame-load", this._onFrameLoad);
        this.element.addEventListener("mouseenter", this._onEnter);
        this.element.addEventListener("mouseleave", this._onLeave);
        document.addEventListener("keydown", this._onKeydown);
    }

    disconnect() {
        this.element.removeEventListener("turbo:frame-load", this._onFrameLoad);
        this.element.removeEventListener("mouseenter", this._onEnter);
        this.element.removeEventListener("mouseleave", this._onLeave);
        document.removeEventListener("keydown", this._onKeydown);
        clearTimeout(this._timer);
    }

    // Wait for the frame to settle (headers are only rendered after it loads).
    _schedule() {
        if (this._started) return;
        clearTimeout(this._timer);
        this._timer = setTimeout(() => this._start(), 300);
    }

    // `force` replays every available segment, e.g. when the user presses ?.
    _start(force = false) {
        if ((this._started && !force) || window.__mensaTourActive) return;

        const segments = SEGMENTS.filter(
            (s) => (force || !this._seen(s.key)) && this.element.querySelector(s.selector),
        );
        if (segments.length === 0) return;

        this._started = true;
        window.__mensaTourActive = true;

        const hint = this.textsValue.ui?.replay_hint;
        const steps = segments.map((s, index) => {
            let description = this._description(s.key);
            if (hint && index === segments.length - 1) description += ` ${hint}`;
            const step = {
                element: () => this.element.querySelector(s.selector),
                popover: {
                    title: this.textsValue[s.key]?.title,
                    description,
                },
            };
            if (s.key === "export") this._makeExportInteractive(step);
            return step;
        });

        segments.forEach((s) => this._markSeen(s.key));

        const ui = this.textsValue.ui || {};
        const tour = driver({
            showProgress: true,
            steps,
            nextBtnText: ui.next,
            prevBtnText: ui.previous,
            doneBtnText: ui.done,
            progressText: ui.progress,
            onDestroyed: () => {
                window.__mensaTourActive = false;
            },
        });
        this._activeTour = tour;
        tour.drive();
    }

    // Next on the export step opens the dialog and continues with the dialog tour.
    _makeExportInteractive(step) {
        step.popover.nextBtnText = this.textsValue.ui?.next;
        step.popover.onNextClick = (el) => {
            this._activeTour?.destroy();
            el?.click();
            setTimeout(() => this._startDialogTour(), 400);
        };
    }

    _startDialogTour() {
        const dialog = this.element.querySelector("dialog.mensa-table__export-dialog");
        if (!dialog?.open) return;

        const keys = ["export_list", "export_scope", "export_format", "export_repeat"];
        const steps = keys
            .filter((key) => dialog.querySelector(`[data-mensa-tour='${key}']`))
            .map((key) => ({
                element: () => dialog.querySelector(`[data-mensa-tour='${key}']`),
                popover: {
                    title: this.textsValue[key]?.title,
                    description: this.textsValue[key]?.description,
                },
            }));
        if (steps.length === 0) return;

        const ui = this.textsValue.ui || {};
        window.__mensaTourActive = true;
        // The modal dialog lives in the top layer, so the popover has to be moved inside it.
        let wrapper;
        const tour = driver({
            showProgress: true,
            overlayOpacity: 0,
            steps,
            nextBtnText: ui.next,
            prevBtnText: ui.previous,
            doneBtnText: ui.done,
            progressText: ui.progress,
            onPopoverRender: (popover) => {
                wrapper = popover.wrapper;
                dialog.appendChild(wrapper);
            },
            // Driver removes the previous popover from document.body, so put it back first.
            onNextClick: (_el, _step, { driver: d }) => {
                document.body.appendChild(wrapper);
                d.moveNext();
            },
            onPrevClick: (_el, _step, { driver: d }) => {
                document.body.appendChild(wrapper);
                d.movePrevious();
            },
            onDestroyed: () => {
                window.__mensaTourActive = false;
                if (dialog.open) dialog.close();
            },
        });
        tour.drive();
    }

    _description(key) {
        const text = this.textsValue[key]?.description || "";
        if (key !== "search") return text;

        const filterable =
            this.element.querySelector("[data-mensa-tour='search']")?.dataset
                .mensaTourFilterable === "true";
        return filterable ? text : this.textsValue.search?.description_only || text;
    }

    _seen(key) {
        try {
            return window.localStorage.getItem(STORAGE_PREFIX + key) === "1";
        } catch (e) {
            return false;
        }
    }

    _markSeen(key) {
        try {
            window.localStorage.setItem(STORAGE_PREFIX + key, "1");
        } catch (e) {}
    }
}
