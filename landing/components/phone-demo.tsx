"use client";
import { useState } from "react";
import {
  ArrowRight,
  Check,
  Leaf,
  RotateCcw,
  Signal,
  BatteryFull,
} from "lucide-react";
const options = ["Амт, чанар", "Орц, найрлага", "Сав баглаа боодол"];
export function PhoneDemo() {
  const [answer, setAnswer] = useState<string | null>(null);
  const [done, setDone] = useState(false);
  return (
    <div className="demo-composition">
      <div className="floating-note">
        <span className="note-icon">
          <Check size={18} />
        </span>
        <div>
          <strong>Жижиг санал.</strong>
          <span>Том өөрчлөлтийн эхлэл.</span>
        </div>
      </div>
      <div className="phone">
        <div className="phone-status" aria-hidden>
          <b>9:41</b>
          <span className="phone-island" />
          <span>
            <Signal size={13} />
            <BatteryFull size={17} />
          </span>
        </div>
        <div className="phone-content">
          <div className="phone-brand">
            uziy<span>.</span>
            <span className="demo-label">ТУРШИЛТ</span>
          </div>
          <div className="product-art" aria-hidden>
            <span className="product-label">
              ӨДӨР БҮРД
              <br />
              ШИНЭ СОНГОЛТ.
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
              Байгальд
              <br />
              ойрхон.
            </span>
          </div>
          <div className="demo-body">
            {done ? (
              <div className="demo-success" role="status">
                <span className="success-icon">
                  <Check size={28} />
                </span>
                <h3>Таны санал үнэ цэнтэй.</h3>
                <p>Энэ бол жишээ асуулга. Таны хариултыг хадгалаагүй.</p>
                <button
                  className="demo-submit"
                  onClick={() => {
                    setDone(false);
                    setAnswer(null);
                  }}
                >
                  Дахин турших <RotateCcw size={15} />
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
                  <span>Таны сонголт</span>
                  <span>01 / 01</span>
                </div>
                <fieldset>
                  <legend>
                    Ундаа сонгохдоо юуг хамгийн түрүүнд хардаг вэ?
                  </legend>
                  {options.map((o) => (
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
                  Санал өгөх <ArrowRight size={16} />
                </button>
              </form>
            )}
          </div>
          <p className="demo-disclaimer">
            Зөвхөн танилцуулах зориулалттай жишээ
          </p>
        </div>
        <div className="phone-home" aria-hidden />
      </div>
      <span className="floating-tag">Таны бодол чухал ↗</span>
    </div>
  );
}
