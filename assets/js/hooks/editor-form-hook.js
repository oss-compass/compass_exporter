import { basicSetup } from "codemirror";
import { Decoration, EditorView, keymap } from "@codemirror/view";
import { defaultKeymap, indentWithTab } from "@codemirror/commands";
import { EditorState, Compartment, StateField, StateEffect } from "@codemirror/state";
import { yaml } from "@codemirror/lang-yaml";

let language = new Compartment, readOnlyMode = new Compartment;

let textarea = document.getElementById("editdata");

let updateListenerExtension = EditorView.updateListener.of((update) => {
  if (update.docChanged) {
    textarea.value = update.state.doc.toString();
    let highlights = [];
    for (let i = 1; i < update.state.doc.lines; i++) {
      let line = update.state.doc.line(i);
      if (line.text.startsWith('+')) {
        highlights.push(addLineHighlight.of(update.state.doc.line(i).from));
      } else if (line.text.startsWith('-')) {
        highlights.push(removeLineHighlight.of(update.state.doc.line(i).from));
      }
    }
    view.dispatch({effects: highlights});
    textarea.dispatchEvent(
      new Event("input", {bubbles: true})
    );
  }
});

const addLineHighlight = StateEffect.define();
const removeLineHighlight = StateEffect.define();

const addLineHighlightField = StateField.define({
  create() {
    return Decoration.none;
  },
  update(lines, tr) {
    lines = lines.map(tr.changes);
    for (let e of tr.effects) {
      if (e.is(addLineHighlight)) {
        lines = lines.update({add: [addLineHighlightMark.range(e.value)]});
      }
    }
    return lines;
  },
  provide: (f) => EditorView.decorations.from(f),
});

const removeLineHighlightField = StateField.define({
  create() {
    return Decoration.none;
  },
  update(lines, tr) {
    lines = lines.map(tr.changes);
    for (let e of tr.effects) {
      if (e.is(removeLineHighlight)) {
        lines = lines.update({add: [removeLineHighlightMark.range(e.value)]});
      }
    }
    return lines;
  },
  provide: (f) => EditorView.decorations.from(f),
});

const removeLineHighlightMark = Decoration.line({
  attributes: {style: 'background-color: #FFEAE8'},
});

const addLineHighlightMark = Decoration.line({
  attributes: {style: 'background-color: #DFFFED'},
});


let state = EditorState.create({
  extensions: [
    basicSetup,
    language.of(yaml()),
    addLineHighlightField,
    removeLineHighlightField,
    updateListenerExtension,
    readOnlyMode.of(EditorState.readOnly.of(false)),
    keymap.of([
      defaultKeymap,
      indentWithTab
    ])
  ]
});
let view = new EditorView({
  state: state,
  parent: document.getElementById("editor")
});

const EditorFormHook = {
  mounted() {

    // Initialise the editor with the content from the form's textarea
    let content = textarea.value;
    let new_state = view.state.update({
      changes: { from: 0, to: view.state.doc.length, insert: content }
    });
    view.dispatch(new_state);

    // Synchronise the form's textarea with the editor on submit
    this.el.form.addEventListener("submit", (_event) => {
      textarea.value = view.state.doc.toString();
    });

    window.addEventListener("phx:set-read-only", (event) => {
      console.log(event.detail);
      view.dispatch({
        effects: readOnlyMode.reconfigure(EditorState.readOnly.of(event.detail.value))
      });
    });

    window.addEventListener("phx:update-editor", (event) => {
      let new_state = view.state.update({
        changes: { from: 0, to: view.state.doc.length, insert: event.detail.content }
      });
      view.dispatch(new_state)
    });
  }
};

export default EditorFormHook;
