import { LightningElement,api } from 'lwc';

export default class NacStageIndicator extends LightningElement {
    @api stages;
    @api currentStage;
}