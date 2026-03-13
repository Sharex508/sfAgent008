# Copado Direct Sales Flow - Step-by-Step (Manual Video Review)

Source video:
`C:\Users\narendra\Downloads\CopadoCrtTestsNattDirectSaleOppManagementCCRN3612Directsalesnewflow.mp4`

Review method:
- Deterministic frame extraction (no video LLM narration)
- Manual timeline reconstruction from extracted keyframes
- Keyframe artifacts saved under `data/manual_video_review`

## 1) Timeline of the observed flow

1. `00:00:00` Open **Accounts** list in NATT Sales app (recently viewed).
2. `00:00:06` Navigate into Account detail pages (`Test Direct Sales Account` / similar account tabs).
3. `00:01:42` Open Opportunity record `Nicole Fleming` (Account: `Test Direct Sales Account`).
4. `00:01:50` From Account/Opportunity context, open **Create Opportunity** modal.
5. `00:02:10` Opportunity edit view is shown; required fields are being prepared.
6. `00:02:38` Opportunity stage is set from earlier value to **Qualification** (later moved to Quoting).
7. `00:03:04` Error banner shown: **"You cannot create a quote unless the Opportunity stage is 'Quoting'"**.
8. `00:03:26` Open **New Opportunity Requested Ship Date** form (`Opportunity_Scheduled_Pick_Date__c` flow).
9. `00:03:38` Save succeeds for record like `OSPD-1624` ("Opportunity Requested Ship Date ... was created.").
10. `00:03:42` Return to Opportunity related tab; `Opportunity Requested Ship Dates` list shows entries.
11. `00:04:00` Attempt **Add Products** in opportunity context; error shown first indicating product dependency.
12. `00:04:06` In **Edit Selected Products**, choose product `Vector 8600 - System 16`, adjust qty/price.
13. `00:04:16` Success toast confirms opportunity product update.
14. `00:04:48` Opportunity now shows Stage `Quoting`, Products present, and multiple Requested Ship Date rows.
15. `00:07:20` Open Quote editor (`Q-25088`, `Edit Quote`) and set quote configuration fields.
16. `00:09:28` On Quote detail, click **Submit for Approval** and enter approval comment.
17. `00:10:00` Quote `Q-25088` appears with status **Approved** later in the run.
18. `00:10:10` On Opportunity page, run **Clone Deal & Quote** action.
19. `00:12:46` New cloned quote appears (`Q-25089`) tied to cloned opportunity.
20. `00:14:52` In **Approval History**, approver (Kevin) clicks **Approve**.
21. `00:16:44` In **Approval History**, another approver context (Donna) clicks **Approve**.
22. `00:26:40` Search/result check shows additional quote (`Q-25090`) in `Pending Approval`.
23. `00:36:22` Search/result check shows additional quote (`Q-25091`) in `Pending Approval`.
24. `00:40:12` Final verification on Opportunity -> **Orders** related list with multiple clone-linked rows.

## 2) Core business rules confirmed by the video

1. Quote creation/submission is gated by opportunity stage; stage must be `Quoting`.
2. Quote flow depends on opportunity products existing.
3. Requested ship date records are created/updated as part of the opportunity direct-sales process.
4. Approval is multi-step and may require actions from different approver users.
5. Clone Deal & Quote creates new quote/opportunity artifacts (`...-Clone`) and repeats approval flow.

## 3) Actors and records observed

1. Primary working account/opportunity context:
- Account: `Test Direct Sales Account`
- Opportunity: `Nicole Fleming`

2. Frequently observed users:
- `Kinna Vichathep` (main creator/editor)
- `Kevin Fleeman` (approval actor)
- `Donna Dowell` (approval actor)

3. Frequently observed quotes:
- `Q-25088` (approved)
- `Q-25089` (clone path, approval actions shown)
- `Q-25090`, `Q-25091` (pending approval observed in search/results)

4. Product observed:
- `Vector 8600 - System 16`

## 4) Confidence notes

1. Exact click-level values (every form field) are high confidence for key mandatory actions.
2. Some repeated cycles are compressed in this document to keep signal over noise.
3. Approval and clone loops were repeated several times across the 40-minute run.

