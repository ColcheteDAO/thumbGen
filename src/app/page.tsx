"use client"
import '@pqina/pintura/pintura.css';
import './App.css';
import { PinturaEditor } from '@pqina/react-pintura';
import {
    getEditorDefaults,
    createMarkupEditorToolStyle,
    createMarkupEditorToolStyles,
} from '@pqina/pintura';

const editorDefaults = getEditorDefaults();

function Home() {
    return (
        <div className="App">
            <PinturaEditor
                {...editorDefaults}
                src={'image.jpeg'}
                markupEditorToolStyles={createMarkupEditorToolStyles({
                    text: createMarkupEditorToolStyle('text', {
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
                    }),
                })}
            />
        </div>
    );
}

export default Home;
