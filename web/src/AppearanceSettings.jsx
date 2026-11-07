import { useState } from "react";
import { appearanceAreas, appearanceLayout, appearanceLayoutControls, areaPaint, colourChannels, paintBackground } from "./appearance.js";
import { appearancePresets } from "./appearancePresets.js";
import { inventoryState, setInventoryAppearance } from "./inventoryStore.js";

const channelLabels = ["Red", "Green", "Blue"];

function Slider({ label, min = 0, max, value, suffix = "", onChange }) {
  return (
    <label className="appearance-slider">
      <span>{label} <output>{value}{suffix}</output></span>
      <input type="range" aria-label={label} min={min} max={max} value={value}
        onChange={(event) => onChange(Number(event.target.value))} />
    </label>
  );
}

function ColourPicker({ label, colour, opacity, onColour, onOpacity }) {
  const channels = colourChannels(colour);
  const changeChannel = (index, value) => {
    const updated = channels.map((channel, channelIndex) => channelIndex === index ? value : channel);
    onColour(`#${updated.map((channel) => channel.toString(16).padStart(2, "0")).join("")}`);
  };
  return (
    <fieldset className="appearance-colour">
      <legend>{label}</legend>
      <div className="appearance-colour-value">
        <span aria-hidden="true" style={{ background: colour }} />
        <code>{colour.toUpperCase()}</code>
      </div>
      {channelLabels.map((channel, index) => (
        <Slider key={channel} label={channel} max={255} value={channels[index]}
          onChange={(value) => changeChannel(index, value)} />
      ))}
      <Slider label="Opacity" max={100} value={opacity} suffix="%" onChange={onOpacity} />
    </fieldset>
  );
}

export function AppearanceSettings({ saving }) {
  const [areaKey, setAreaKey] = useState("accent");
  const settings = inventoryState.settingsDraft;
  const area = appearanceAreas.find((entry) => entry.key === areaKey);
  const paint = areaPaint(area, settings);
  const gradient = paint.mode === "gradient";
  const layout = appearanceLayout(settings);
  const update = (changes) => setInventoryAppearance({
    ...settings.appearance,
    [area.key]: { ...paint, ...changes },
  });

  return (
    <fieldset className="appearance-editor" disabled={saving}>
      <legend className="appearance-legend">Theme colours</legend>
      <div className="appearance-presets" role="group" aria-label="Theme presets">
        {appearancePresets.map(({ id, label, theme }) => (
          <button key={id} type="button" onClick={() => setInventoryAppearance(theme)}>
            <span aria-hidden="true" style={{ background: paintBackground(theme.accent) }} />
            {label}
          </button>
        ))}
      </div>
      <div className="appearance-preview" aria-label="Inventory theme preview">
        <div className="appearance-preview-title">Inventory preview</div>
        <div className="appearance-preview-grid">
          <span><img src="images/bandage.png" alt="Bandage" /></span>
          <span className="appearance-preview-empty" />
          <span className="appearance-preview-selected" />
        </div>
      </div>
      <div className="appearance-options">
        <label>Area
          <select value={areaKey} onChange={(event) => setAreaKey(event.target.value)}>
            <optgroup label="Surfaces">
              {appearanceAreas.filter((entry) => !entry.solidOnly).map((entry) => <option key={entry.key} value={entry.key}>{entry.label}</option>)}
            </optgroup>
            <optgroup label="Text and indicators">
              {appearanceAreas.filter((entry) => entry.solidOnly).map((entry) => <option key={entry.key} value={entry.key}>{entry.label}</option>)}
            </optgroup>
          </select>
        </label>
        {!area.solidOnly && <label>Fill
          <select value={paint.mode} onChange={(event) => update({ mode: event.target.value })}>
            <option value="solid">Solid</option>
            <option value="gradient">Gradient</option>
          </select>
        </label>}
      </div>
      <div className="appearance-swatch" aria-hidden="true" style={{ background: paintBackground(paint) }} />
      <div className="appearance-colours">
        <ColourPicker label={gradient ? "First colour" : "Colour"} colour={paint.first} opacity={paint.firstOpacity}
          onColour={(first) => update({ first })} onOpacity={(firstOpacity) => update({ firstOpacity })} />
        {gradient && <ColourPicker label="Second colour" colour={paint.second} opacity={paint.secondOpacity}
          onColour={(second) => update({ second })} onOpacity={(secondOpacity) => update({ secondOpacity })} />}
      </div>
      {gradient && <div className="appearance-gradient">
        <Slider label="Direction" max={360} value={paint.angle} suffix="°" onChange={(angle) => update({ angle })} />
        <Slider label="First colour balance" min={1} max={99} value={paint.balance} suffix="%" onChange={(balance) => update({ balance })} />
      </div>}
      <div className="appearance-layout">
        <h4>Shape and spacing</h4>
        {appearanceLayoutControls.map(({ key, label, max }) => (
          <Slider key={key} label={label} max={max} value={layout[key]} suffix=" px"
            onChange={(value) => setInventoryAppearance({
              ...settings.appearance,
              layout: { ...settings.appearance?.layout, [key]: value },
            })} />
        ))}
      </div>
      <button type="button" onClick={() => setInventoryAppearance({})}>Reset theme</button>
    </fieldset>
  );
}
