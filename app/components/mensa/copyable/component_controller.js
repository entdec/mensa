import ApplicationController from "mensa/controllers/application_controller";

export default class CopyableComponentController extends ApplicationController {
    static values = {
        text: String,
    };

    async copy(event) {
        event.preventDefault();

        if (!this.hasTextValue) return;

        if (navigator.clipboard?.writeText) {
            await navigator.clipboard.writeText(this.textValue);
        } else {
            this._copyWithFallback(this.textValue);
        }
    }

    _copyWithFallback(text) {
        const input = document.createElement("textarea");
        input.value = text;
        input.setAttribute("readonly", "");
        input.style.position = "fixed";
        input.style.top = "-9999px";
        input.style.left = "-9999px";
        document.body.appendChild(input);
        input.select();
        document.execCommand("copy");
        input.remove();
    }
}
