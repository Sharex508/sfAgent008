import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getEnvironmentContext from '@salesforce/apex/AgentFeatureController.getEnvironmentContext';
import getUiFeatures from '@salesforce/apex/AgentFeatureController.getUiFeatures';
import getUiFeature from '@salesforce/apex/AgentFeatureController.getUiFeature';
import createUiFeature from '@salesforce/apex/AgentFeatureController.createUiFeature';
import updateUiFeature from '@salesforce/apex/AgentFeatureController.updateUiFeature';
import getUiFeatureRuns from '@salesforce/apex/AgentFeatureController.getUiFeatureRuns';
import getUiFeatureRunArtifacts from '@salesforce/apex/AgentFeatureController.getUiFeatureRunArtifacts';
import runUiFeature from '@salesforce/apex/AgentFeatureController.runUiFeature';

const LOGIN_MODE_OPTIONS = [
    { label: 'CLI Access Token', value: 'cli_access_token' },
    { label: 'Manual', value: 'manual' },
    { label: 'SSO', value: 'sso' },
    { label: 'Storage State', value: 'storage_state' }
];

const DEFAULT_STEPS = JSON.stringify(
    [
        { name: 'Open record', action: 'goto', url: '/lightning/r/Account/001000000000001/view' },
        { name: 'Wait for card', action: 'expect_visible', selector: "[data-id='nps-card']" }
    ],
    null,
    2
);

export default class AgentFeatureConsole extends LightningElement {
    @track environmentContext;
    @track endpointBase = '';
    @track apiKey = '';
    @track selectedFeatureId = '';
    @track featureList = [];
    @track runList = [];
    @track artifacts;
    @track isLoading = false;
    @track isRunning = false;

    @track featureName = '';
    @track featureDescription = '';
    @track targetOrgAlias = '';
    @track metadataProjectDir = '';
    @track appName = '';
    @track pageContext = '';
    @track startUrl = '';
    @track loginMode = 'cli_access_token';
    @track tagsText = '';
    @track expectedOutcomesText = '';
    @track stepsJsonText = DEFAULT_STEPS;
    @track notes = '';

    @track runBaseUrl = '';
    @track runHeadless = true;
    @track runRecordVideo = true;
    @track runRecordTrace = true;
    @track runTimeoutMs = 15000;

    connectedCallback() {
        this.initialize();
    }

    async initialize() {
        try {
            this.environmentContext = await getEnvironmentContext();
        } catch (error) {
            this.handleError('Environment load failed', error);
        }
    }

    get loginModeOptions() {
        return LOGIN_MODE_OPTIONS;
    }

    get hasFeatures() {
        return this.featureList.length > 0;
    }

    get hasRuns() {
        return this.runList.length > 0;
    }

    get screenshotArtifacts() {
        return this.artifacts?.screenshots || [];
    }

    get hasScreenshots() {
        return this.screenshotArtifacts.length > 0;
    }

    get environmentOrgLabel() {
        return this.environmentContext?.orgName || 'Current org';
    }

    get environmentDomainLabel() {
        return this.environmentContext?.orgDomainUrl || 'Unknown domain';
    }

    get saveButtonLabel() {
        return this.selectedFeatureId ? 'Update Feature' : 'Save Feature';
    }

    handleInputChange(event) {
        const { name, value, checked, type } = event.target;
        this[name] = type === 'toggle' ? checked : value;
    }

    async handleRefreshFeatures() {
        if (!this.endpointBase) {
            this.showToast('Missing Endpoint', 'Enter the backend endpoint base first.', 'error');
            return;
        }
        this.isLoading = true;
        try {
            const raw = await getUiFeatures({ endpointBase: this.endpointBase, apiKey: this.apiKey });
            const payload = JSON.parse(raw);
            this.featureList = payload.items || [];
            if (this.selectedFeatureId) {
                const match = this.featureList.find((item) => item.feature_id === this.selectedFeatureId);
                if (!match) {
                    this.selectedFeatureId = '';
                    this.runList = [];
                    this.artifacts = null;
                }
            }
        } catch (error) {
            this.handleError('Feature refresh failed', error);
        } finally {
            this.isLoading = false;
        }
    }

    async handleSelectFeature(event) {
        const featureId = event.currentTarget.dataset.id;
        if (!featureId) {
            return;
        }
        this.selectedFeatureId = featureId;
        await this.loadFeature(featureId);
    }

    async loadFeature(featureId) {
        this.isLoading = true;
        try {
            const raw = await getUiFeature({ endpointBase: this.endpointBase, apiKey: this.apiKey, featureId });
            const feature = JSON.parse(raw);
            this.featureName = feature.name || '';
            this.featureDescription = feature.description || '';
            this.targetOrgAlias = feature.target_org_alias || '';
            this.metadataProjectDir = feature.metadata_project_dir || '';
            this.appName = feature.app_name || '';
            this.pageContext = feature.page_context || '';
            this.startUrl = feature.start_url || '';
            this.loginMode = feature.login_mode || 'cli_access_token';
            this.tagsText = (feature.tags || []).join(', ');
            this.expectedOutcomesText = (feature.expected_outcomes || []).join('\n');
            this.stepsJsonText = JSON.stringify(feature.steps || [], null, 2);
            this.notes = feature.notes || '';
            this.runBaseUrl = '';
            await this.loadRuns(featureId);
        } catch (error) {
            this.handleError('Feature load failed', error);
        } finally {
            this.isLoading = false;
        }
    }

    async loadRuns(featureId) {
        const raw = await getUiFeatureRuns({ endpointBase: this.endpointBase, apiKey: this.apiKey, featureId });
        const payload = JSON.parse(raw);
        this.runList = payload.runs || [];
        if (this.runList.length > 0) {
            await this.loadArtifacts(featureId, this.runList[0].run_id);
        } else {
            this.artifacts = null;
        }
    }

    async loadArtifacts(featureId, runId) {
        const raw = await getUiFeatureRunArtifacts({
            endpointBase: this.endpointBase,
            apiKey: this.apiKey,
            featureId,
            runId
        });
        const payload = JSON.parse(raw);
        this.artifacts = this.decorateArtifactUrls(payload);
    }

    decorateArtifactUrls(payload) {
        const withBase = (path) => {
            if (!path) {
                return null;
            }
            return `${this.endpointBase.replace(/\/$/, '')}${path}`;
        };
        const screenshots = (payload.screenshots || []).map((item) => ({
            ...item,
            resolvedUrl: withBase(item.url_path)
        }));
        return {
            ...payload,
            videoUrl: withBase(payload.video_url_path),
            traceUrl: withBase(payload.trace_url_path),
            summaryUrl: withBase(payload.summary_url_path),
            screenshots
        };
    }

    async handleSaveFeature() {
        if (!this.endpointBase) {
            this.showToast('Missing Endpoint', 'Enter the backend endpoint base first.', 'error');
            return;
        }
        this.isLoading = true;
        try {
            const payload = this.buildFeaturePayload();
            let raw;
            if (this.selectedFeatureId) {
                raw = await updateUiFeature({
                    endpointBase: this.endpointBase,
                    apiKey: this.apiKey,
                    featureId: this.selectedFeatureId,
                    requestJson: JSON.stringify(payload)
                });
            } else {
                raw = await createUiFeature({
                    endpointBase: this.endpointBase,
                    apiKey: this.apiKey,
                    requestJson: JSON.stringify(payload)
                });
            }
            const feature = JSON.parse(raw);
            this.selectedFeatureId = feature.feature_id;
            await this.handleRefreshFeatures();
            await this.loadFeature(feature.feature_id);
            this.showToast('Saved', 'UI feature saved successfully.', 'success');
        } catch (error) {
            this.handleError('Feature save failed', error);
        } finally {
            this.isLoading = false;
        }
    }

    async handleRunFeature() {
        if (!this.endpointBase) {
            this.showToast('Missing Endpoint', 'Enter the backend endpoint base first.', 'error');
            return;
        }
        this.isRunning = true;
        try {
            if (!this.selectedFeatureId) {
                await this.handleSaveFeature();
            }
            const runPayload = {
                target_org_alias: this.targetOrgAlias || null,
                base_url: this.runBaseUrl || null,
                headless: this.runHeadless,
                record_video: this.runRecordVideo,
                record_trace: this.runRecordTrace,
                timeout_ms: Number(this.runTimeoutMs) || 15000
            };
            const raw = await runUiFeature({
                endpointBase: this.endpointBase,
                apiKey: this.apiKey,
                featureId: this.selectedFeatureId,
                requestJson: JSON.stringify(runPayload)
            });
            const run = JSON.parse(raw);
            await this.loadRuns(this.selectedFeatureId);
            await this.loadArtifacts(this.selectedFeatureId, run.run_id);
            this.showToast('Run Completed', `UI feature run finished with status ${run.status}.`, run.status === 'PASSED' ? 'success' : 'warning');
        } catch (error) {
            this.handleError('Feature run failed', error);
        } finally {
            this.isRunning = false;
        }
    }

    buildFeaturePayload() {
        let steps;
        try {
            steps = JSON.parse(this.stepsJsonText || '[]');
        } catch (error) {
            throw new Error('Steps JSON is invalid.');
        }
        if (!Array.isArray(steps) || !steps.length) {
            throw new Error('Provide at least one UI step.');
        }
        if (!this.featureName) {
            throw new Error('Feature name is required.');
        }
        return {
            name: this.featureName,
            description: this.featureDescription || null,
            target_org_alias: this.targetOrgAlias || null,
            metadata_project_dir: this.metadataProjectDir || null,
            app_name: this.appName || null,
            page_context: this.pageContext || null,
            start_url: this.startUrl || null,
            login_mode: this.loginMode || 'cli_access_token',
            steps,
            expected_outcomes: this.expectedOutcomesText
                ? this.expectedOutcomesText.split('\n').map((item) => item.trim()).filter(Boolean)
                : [],
            tags: this.tagsText
                ? this.tagsText.split(',').map((item) => item.trim()).filter(Boolean)
                : [],
            notes: this.notes || null
        };
    }

    handleError(title, error) {
        let message = 'Unknown error';
        if (error?.body?.message) {
            message = error.body.message;
        } else if (error?.message) {
            message = error.message;
        } else if (typeof error === 'string') {
            message = error;
        }
        this.showToast(title, message, 'error');
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}
