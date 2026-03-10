import { LightningElement, track } from 'lwc';
import CARRIER_LOGO from '@salesforce/resourceUrl/CarrierWebToLeadLogo';
import BG_IMG from '@salesforce/resourceUrl/CarrierWebToLeadBackground';

// Labels / dynamic ids
import ORG_ID from '@salesforce/label/c.OrgId';
import THANK_YOU_URL from '@salesforce/label/c.ThankYouUrl';
import WEB_TO_LEAD_HOST from '@salesforce/label/c.WebToLeadHost';
import LANGUAGE_FIELD_ID from '@salesforce/label/c.LanguageFieldId';
import COMMENTS_FIELD_ID from '@salesforce/label/c.CommentsFieldId';
import CONTAINER_RT_ID from '@salesforce/label/c.ContainerLeadRecTypeId';
import PRODUCTS_INT_FIELD_ID from '@salesforce/label/c.ProductsIntFieldId';
import VISIT_PURPOSE_FIELD_ID from '@salesforce/label/c.VisitPurpousFieldId';
import OTHER_PRODUCTS_INT_FIELD_ID from '@salesforce/label/c.OtherProductsIntFieldId';
import OTHER_VISIT_PURPOSE_FIELD_ID from '@salesforce/label/c.OtherVisitPurpousFieldId';

export default class Container_WebToLead extends LightningElement {
  carrierLogoUrl = CARRIER_LOGO;

  // dynamic SF ids
  orgId = ORG_ID;
  LanguageValue = 'English';
  LeadSource = 'Container Web To Lead';
  CommentsFieldId = COMMENTS_FIELD_ID;
  LanguageFieldId = LANGUAGE_FIELD_ID;
  ContainerLeadRecTypeId = CONTAINER_RT_ID;
  ProductsIntFieldId = PRODUCTS_INT_FIELD_ID;
  VisitPurpousFieldId = VISIT_PURPOSE_FIELD_ID;
  OtherProductsIntFieldId = OTHER_PRODUCTS_INT_FIELD_ID;
  OtherVisitPurpousFieldId = OTHER_VISIT_PURPOSE_FIELD_ID;

  // Inline error messages for iOS Safari (checkbox groups)
  @track vpError = '';
  @track piError = '';

  // background style
  get bgStyle() {
    return `background: url("${BG_IMG}") center/cover no-repeat;`;
  }

  // Privacy policy enforcement
  privacyUrl = 'https://www.carrier.com/carrier/en/worldwide/legal/privacy-notice/';
  privacyLinkOpened = false;
  privacyChecked = false;

  get disableConsent() { return !this.privacyLinkOpened; }
  get isSubmitDisabled() { return !this.privacyChecked; }
  markPrivacyOpened() { this.privacyLinkOpened = true; }
  handlePrivacyCheck(e) { this.privacyChecked = e.target.checked; }

  // Routing
  retURL = THANK_YOU_URL;
  get actionUrl() {
    return `${WEB_TO_LEAD_HOST}/servlet/servlet.WebToLead?encoding=UTF-8`;
  }

  // ---- Visit Purpose ("Other" can be combined; show text only if Other checked) ----
  @track showOtherVisitPurpose = false;

  handleVisitPurposeChange() {
    const otherCb = this.template.querySelector(
      `input[type="checkbox"][name="${this.VisitPurpousFieldId}"][value="Other"]`
    );
    this.showOtherVisitPurpose = !!otherCb?.checked;

    // clear any inline error for this group
    this.vpError = '';
    // clear any prior ARIA error state on the group checkboxes
    this.template.querySelectorAll(`input[type="checkbox"][name="${this.VisitPurpousFieldId}"]`)
      .forEach(cb => cb.removeAttribute('aria-invalid'));

    if (!this.showOtherVisitPurpose) {
      const inp = this.template.querySelector(`[name="${this.OtherVisitPurpousFieldId}"]`);
      if (inp) { inp.value = ''; inp.setCustomValidity(''); }
    }
  }
  clearOtherVisitError() {
    const el = this.template.querySelector(`[name="${this.OtherVisitPurpousFieldId}"]`);
    if (el) el.setCustomValidity('');
  }

  // ---- Products Interested ("Other" can be combined; show text only if Other checked) ----
  @track showOtherProducts = false;

  handleProductsChange() {
    const otherCb = this.template.querySelector(
      `input[type="checkbox"][name="${this.ProductsIntFieldId}"][value="Other"]`
    );
    this.showOtherProducts = !!otherCb?.checked;

    // clear any inline error for this group
    this.piError = '';
    // clear any prior ARIA error state on the group checkboxes
    this.template.querySelectorAll(`input[type="checkbox"][name="${this.ProductsIntFieldId}"]`)
      .forEach(cb => cb.removeAttribute('aria-invalid'));

    if (!this.showOtherProducts) {
      const inp = this.template.querySelector(`[name="${this.OtherProductsIntFieldId}"]`);
      if (inp) { inp.value = ''; inp.setCustomValidity(''); }
    }
  }

  // --- Mobile validation ---
  handleMobileChange(e) {
    this.validateMobile(e.target);
  }
  clearMobileError() {
    const el = this.template.querySelector('#mobile');
    if (el) el.setCustomValidity('');
  }

  /**
   * Robust mobile validator:
   * - Requires element to exist
   * - Must start with '+'
   * - At least 3 digits total (including country code)
   * Returns true if valid; false otherwise.
   */
  validateMobile(el) {
    if (!el) {
      // If the input is missing from the template, block submission explicitly.
      // This avoids "silent submits" when selector fails.
      console.warn('Mobile input not found. Blocking submission.');
      return false;
    }

    const raw = (el.value || '').trim();
    const plusAtStart = raw.startsWith('+');
    const digitCount  = raw.replace(/\D/g, '').length;

     const validPattern = /^\+?[0-9\- ]+$/;

    if (!validPattern.test(raw)) {
      el.setCustomValidity('Invalid Mobile Number');
      el.reportValidity();
      return false;
    }


    if (!plusAtStart) {
      el.setCustomValidity('Phone must start with "+", e.g., +1 123456789.');
      el.reportValidity();
      return false;
    }
    if (digitCount < 3) {
      el.setCustomValidity('Provide mobile number along with country code, e.g., +1 123456789.');
      el.reportValidity();
      return false;
    }
    el.setCustomValidity('');
    return true;
  }

  clearOtherProductsError() {
    const el = this.template.querySelector(`[name="${this.OtherProductsIntFieldId}"]`);
    if (el) el.setCustomValidity('');
  }

  // --- Submit flow (deterministic) ---
  _allowNativeSubmit = false; // prevents recursion when we programmatically submit

  handleSubmit(e) {
    // If this is the programmatic submit we trigger after validation, let it pass.
    if (this._allowNativeSubmit) {
      this._allowNativeSubmit = false; // reset for next time
      return;
    }

    // Always stop the native submit first; well re-submit if all checks pass.
    e.preventDefault();
    e.stopPropagation();

    const form = this.template.querySelector('form');

    // --- 1) PDPA / consent ---
    if (!this.privacyChecked) {
      // Keep the button disabled in UI, but double-gate here too.
      // Put a user-visible error on the consent checkbox if you have one (optional).
      if (form) form.reportValidity();
      return;
    }

    // --- 2) Mobile ---
    const phoneEl = this.template.querySelector('[name="mobile"]') || this.template.querySelector('#mobile');
    if (!this.validateMobile(phoneEl)) {
      return;
    }

    // --- 3) Visit Purpose: at least one OR Other with text ---
    const vpBoxes = [...this.template.querySelectorAll(`input[type="checkbox"][name="${this.VisitPurpousFieldId}"]`)];
    const vpHasAny = vpBoxes.some(cb => cb.checked && cb.value !== 'Other');
    const vpHasOther = vpBoxes.some(cb => cb.checked && cb.value === 'Other');

    if (!vpHasAny && !vpHasOther) {
      this.setGroupError(vpBoxes, 'Select at least one Visit Purpose or choose Other.');
      return;
    }
    if (vpHasOther) {
      const v = this.template.querySelector(`[name="${this.OtherVisitPurpousFieldId}"]`);
      if (!v || !v.value.trim()) {
        if (v) {
          v.setCustomValidity('Please specify the Other Visit Purpose.');
          v.reportValidity();
        }
        return;
      } else {
        v.setCustomValidity('');
      }
    }

    // --- 4) Products Interested: at least one OR Other with text ---
    const piBoxes = [...this.template.querySelectorAll(`input[type="checkbox"][name="${this.ProductsIntFieldId}"]`)];
    const piHasAny = piBoxes.some(cb => cb.checked && cb.value !== 'Other');
    const piHasOther = piBoxes.some(cb => cb.checked && cb.value === 'Other');

    if (!piHasAny && !piHasOther) {
      this.setGroupError(piBoxes, 'Select at least one Product or choose Other.');
      return;
    }
    if (piHasOther) {
      const p = this.template.querySelector(`[name="${this.OtherProductsIntFieldId}"]`);
      if (!p || !p.value.trim()) {
        if (p) {
          p.setCustomValidity('Please specify the Other Products Interested.');
          p.reportValidity();
        }
        return;
      } else {
        p.setCustomValidity('');
      }
    }

    // --- 5) Final: if we got here, submit exactly once ---
    if (form) {
      // Surface any lingering constraint messages just in case
      form.reportValidity();

      // Avoid re-entering handleSubmit by setting a guard flag
      this._allowNativeSubmit = true;

      // Use native submit to honor action/method without re-triggering 'submit' event
      // NOTE: form.submit() doesn’t fire 'submit' again.
      form.submit();
    }
  }

  setGroupError(nodes, msg) {
    if (nodes && nodes.length) {
      // Mark all checkboxes in the group as invalid for accessibility, but avoid native bubbles
      nodes.forEach(n => n.setAttribute('aria-invalid', 'true'));
      const first = nodes[0];

      // Also show inline error text for iOS Safari where checkbox messages may not render
      const groupName = first.getAttribute('name');
      if (groupName === this.VisitPurpousFieldId) {
        this.vpError = msg;
      } else if (groupName === this.ProductsIntFieldId) {
        this.piError = msg;
      }

      // Ensure error area is visible on small screens (e.g., iPhone)
      try {
        const container = first.closest('.form-group') || first;
        container.scrollIntoView({ behavior: 'smooth', block: 'center' });
      } catch (e) {
        // no-op if scrollIntoView unsupported
      }
    } else {
      // Fallback: show at form level if group not found (prevents silent submits)
      const form = this.template.querySelector('form');
      if (form) form.reportValidity();
    }
  }

  // Dynamic classes to visibly mark groups invalid
  get vpGroupClass() {
    return `form-group${this.vpError ? ' has-error' : ''}`;
  }
  get piGroupClass() {
    return `form-group${this.piError ? ' has-error' : ''}`;
  }

  get heroStyle() {
  return `
    background:
      linear-gradient(to bottom, rgba(255,255,255,.12), rgba(255,255,255,.12)),
      url("${BG_IMG}") center/cover no-repeat;
    padding: 20px 16px;
    border-radius: 8px;
  `;
  }
}