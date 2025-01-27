import { defaultQuality } from "./quality";

export const defaultUniforms = {
   uTime: 0.0,
   uQuality: defaultQuality,
   uRotationSpeed: 1,
   uResolution: [window.innerWidth, window.innerHeight],
   uPlanetPosition: [0, 0, 0],
   uRotationOffset: 0.8,
   uPlanetRadius: 2,
   uNoiseStrength: 0.2,
   uTerrainScale: 0.8,
   uCloudsDensity: 0.5,
   uCloudsScale: 1,
   uCloudsSpeed: 1,
   uAtmosphereColor: [0.05, 0.3, 0.9],
   uAtmosphereDensity: 0.3,
   uAmbientLight: 0.002,
   uSunIntensity: 3,
   sunDirectionXY: [1, 1],
};

export type CustomUniforms = typeof defaultUniforms;
