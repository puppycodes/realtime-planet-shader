import { useGlslCanvas } from "../shared/renderer";
import vertexShader from "../shared/shaders/vertex.glsl";
import fragmentShader from "./procedural.fragment.glsl";
import { addPlanetControls } from "../shared/controls/planet.controls";
import { addLightControls } from "../shared/controls/light.controls";
import { addMonitor } from "../shared/controls/monitor.controls";
import { load3DNoiseTexture } from "./noise.loader";
import { addQualityControl } from "../shared/controls/quality.controls";
import { addRotationControls } from "../shared/controls/rotation.controls";
import { defaultUniforms } from "../shared/settings/uniforms";

const canvas = document.querySelector("canvas");

await load3DNoiseTexture(canvas.getContext("webgl2"));

const { uniforms, renderer } = useGlslCanvas(canvas, {
   vertex: vertexShader,
   fragment: fragmentShader,
   uniforms: defaultUniforms,
});

canvas.classList.add("loaded");

const { Pane } = await import("tweakpane");

const pane = new Pane({ title: "Controls" });

addQualityControl(pane, uniforms, renderer);
addRotationControls(pane, uniforms, canvas);
addPlanetControls(pane, uniforms);
addLightControls(pane, uniforms);
addMonitor(pane);
