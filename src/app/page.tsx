"use client"
import React, { useState } from "react";

// react-pintura
import { PinturaEditor } from "@pqina/react-pintura";

// pintura
import { pintura } from "@pqina/pintura/pintura.module.css";
import { index as pinturaTheme } from "./index.module.css";

import {
  // editor
  createDefaultImageReader,
  createDefaultImageWriter,
  createDefaultShapePreprocessor,

  // plugins
  setPlugins,
  plugin_crop,
  plugin_finetune,
  plugin_finetune_defaults,
  plugin_filter,
  plugin_filter_defaults,
  plugin_annotate,
  markup_editor_defaults,
  createMarkupEditorToolStyles,
  createMarkupEditorToolStyle,
} from "@pqina/pintura";

import {
  LocaleCore,
  LocaleCrop,
  LocaleFinetune,
  LocaleFilter,
  LocaleAnnotate,
  LocaleMarkupEditor,
} from "@pqina/pintura/locale/en_GB";
import { text } from "stream/consumers";

setPlugins(plugin_crop, plugin_finetune, plugin_filter, plugin_annotate);

const editorDefaults = {
  utils: ["crop", "finetune", "filter", "annotate"],
  imageReader: createDefaultImageReader(),
  imageWriter: createDefaultImageWriter(),
  shapePreprocessor: createDefaultShapePreprocessor(),
  ...plugin_finetune_defaults,
  ...plugin_filter_defaults,
  ...markup_editor_defaults,
  locale: {
    ...LocaleCore,
    ...LocaleCrop,
    ...LocaleFinetune,
    ...LocaleFilter,
    ...LocaleAnnotate,
    ...LocaleMarkupEditor,
  },
};

export default function Example() {
  // inline
  const [result, setResult] = useState("");

  return (
    <div>
      <h2>Example</h2>

      <div style={{ height: "70vh" }}>
        <PinturaEditor
          {...editorDefaults}
          className={`${pintura} ${pinturaTheme}`}
          src={"./image.jpeg"}
          onLoad={(res) => console.log("load image", res)}
          onProcess={({ dest }) => setResult(URL.createObjectURL(dest))}
          markupEditorToolStyles={createMarkupEditorToolStyles({text:createMarkupEditorToolStyle('text',{
                        // Set default text shape background to transparent
                        backgroundColor: [0, 0, 0, 0],

                        // Set default text shape outline to 0 width and white
                        textOutline: ['0%', [1, 1, 1]],

                        // Set default text shadow, shadow will not be drawn if x, y, and blur are 0.
                        textShadow: ['0%', '0%', '0%', [0, 0, 0, 0.5]],

                        // Allow newlines in inline text
                        disableNewline: false,

                        // Align to left by default, this triggers always showing the text align control
                        textAlign: 'left',

                        // Enable text formatting
                        format: 'html',
                    })})}
        />
      </div>

      {!!result.length && (
        <p>
          <img src={result} alt="" />
        </p>
      )}
    </div>
  );
}
