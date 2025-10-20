import { LightningElement, track } from 'lwc';
import recent from '@salesforce/apex/InteractionSummaryService.recent';
import thread from '@salesforce/apex/InteractionSummaryService.thread';
import recentIncidents from '@salesforce/apex/InteractionSummaryService.recentIncidents';
import markAddressed from '@salesforce/apex/InteractionSummaryService.markAddressed';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

