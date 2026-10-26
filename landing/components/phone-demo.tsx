"use client";
import { useState } from "react";
import {
  ArrowRight,
  Check,
  Leaf,
  RotateCcw,
  Signal,
  Wifi,
  BatteryFull,
} from "lucide-react";
import { DEMO } from "@/lib/content";

/** Multi-line copy ("…\n…") as lines with <br/> between them. */
function Lines({ text }: { text: string }) {
  return text.split("\n").map((line, i) => (
    <span key={line}>
      {i > 0 && <br />}
      {line}
    </span>
  ));
}

/** A one-question sample survey in a phone frame; nothing is sent anywhere. */
export function PhoneDemo() {
  const [answer, setAnswer] = useState<string | null>(null);
  const [done, setDone] = useState(false);
  return (
    <div className="demo-composition">
      <div className="phone">
        {/* Hardware: action + volume keys on the left, side key on the right. */}
        <span className="phone-key phone-key-action" aria-hidden />
        <span className="phone-key phone-key-volume-up" aria-hidden />
        <span className="phone-key phone-key-volume-down" aria-hidden />
        <span className="phone-key phone-key-side" aria-hidden />
        <div className="phone-screen">
          <div className="phone-status" aria-hidden>
            <b>9:41</b>
            <span className="phone-island" />
            <span>
              <Signal size={14} strokeWidth={2.6} />
              <Wifi size={14} strokeWidth={2.6} />
              <BatteryFull size={20} strokeWidth={2} />
            </span>
          </div>
          <div className="phone-content">
            <div className="phone-brand">
              uziy<span>.</span>
              <span className="demo-label">{DEMO.sampleBadge}</span>
            </div>
            <div className="product-art" aria-hidden>
              <span className="product-label">
                <Lines text={DEMO.productTitle} />
              </span>
              <div className="product-can">
                <Leaf size={27} />
                <b>
                  өдөр<span>.</span>
                </b>
                <small>НОГООН ЦАЙ</small>
                <span className="can-line" />
                <small>250 ml</small>
              </div>
              <span className="art-stamp">
                <Lines text={DEMO.productStamp} />
              </span>
            </div>
            <div className="demo-body">
              {done ? (
                <div className="demo-success" role="status">
                  <span className="success-icon">
                    <Check size={28} />
                  </span>
                  <h3>{DEMO.doneTitle}</h3>
                  <p>{DEMO.doneText}</p>
                  <button
                    className="demo-submit"
                    onClick={() => {
                      setDone(false);
                      setAnswer(null);
                    }}
                  >
                    {DEMO.retry} <RotateCcw size={15} aria-hidden />
                  </button>
                </div>
              ) : (
                <form
                  onSubmit={(e) => {
                    e.preventDefault();
                    if (answer) setDone(true);
                  }}
                >
                  <div className="question-meta">
                    <span>{DEMO.questionLabel}</span>
                    <span>{DEMO.questionCount}</span>
                  </div>
                  <fieldset>
                    <legend>{DEMO.question}</legend>
                    {DEMO.options.map((o) => (
                      <label className="demo-option" key={o}>
                        <input
                          type="radio"
                          name="demo-answer"
                          value={o}
                          checked={answer === o}
                          onChange={() => setAnswer(o)}
                        />
                        <span>{o}</span>
                      </label>
                    ))}
                  </fieldset>
                  <button
                    type="submit"
                    className="demo-submit"
                    disabled={!answer}
                  >
                    {DEMO.submit} <ArrowRight size={16} aria-hidden />
                  </button>
                </form>
              )}
            </div>
            <p className="demo-disclaimer">{DEMO.disclaimer}</p>
          </div>
          <div className="phone-home" aria-hidden />
        </div>
      </div>
    </div>
  );
}
