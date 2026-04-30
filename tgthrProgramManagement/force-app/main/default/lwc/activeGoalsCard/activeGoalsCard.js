import { LightningElement, api, wire } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import getGoalAssignments from '@salesforce/apex/GoalAssignmentController.getGoalAssignments';

const INACTIVE_STATUSES = new Set(['Cancelled', 'Closed', 'Completed', 'Inactive', 'Resolved']);
const DUE_SOON_DAYS = 14;
const DAY_IN_MS = 24 * 60 * 60 * 1000;

export default class ActiveGoalsCard extends LightningElement {
    @api recordId;
    @api objectApiName;

    goals = [];
    inactiveGoalCount = 0;
    isLoading = true;
    error = null;
    wiredResult;

    @wire(getGoalAssignments, { caseId: '$caseRecordId', accountId: '$accountRecordId' })
    wiredGoals(result) {
        this.wiredResult = result;
        this.isLoading = false;

        if (result.data) {
            this.error = null;
            this.formatGoals(result.data || []);
        } else if (result.error) {
            this.goals = [];
            this.inactiveGoalCount = 0;
            this.error = this.reduceErrors(result.error);
        }
    }

    get caseRecordId() {
        return this.objectApiName === 'Case' ? this.recordId : null;
    }

    get accountRecordId() {
        return this.objectApiName === 'Account' ? this.recordId : null;
    }

    get hasGoals() {
        return this.goals.length > 0;
    }

    get hasInactiveGoals() {
        return this.inactiveGoalCount > 0;
    }

    get cardTitle() {
        return `Active Goals (${this.goals.length})`;
    }

    get showEmptyState() {
        return !this.isLoading && !this.error && !this.hasGoals;
    }

    async handleRefresh() {
        if (!this.wiredResult) {
            return;
        }

        this.isLoading = true;
        try {
            await refreshApex(this.wiredResult);
        } finally {
            this.isLoading = false;
        }
    }

    formatGoals(rawGoals) {
        const uniqueGoals = this.dedupeGoals(rawGoals);
        const activeGoals = [];
        let inactiveGoalCount = 0;

        uniqueGoals.forEach((goal) => {
            const normalizedStatus = this.normalizeStatus(goal.status);
            if (!this.isActiveStatus(normalizedStatus)) {
                inactiveGoalCount += 1;
                return;
            }

            activeGoals.push(this.formatGoal(goal, normalizedStatus));
        });

        this.inactiveGoalCount = inactiveGoalCount;
        this.goals = activeGoals.sort((left, right) => this.compareGoals(left, right));
    }

    dedupeGoals(rawGoals) {
        const seenIds = new Set();
        const uniqueGoals = [];

        (rawGoals || []).forEach((goal) => {
            const identity = goal.id || [goal.name, goal.caseId, goal.accountId, goal.targetDate].join('|');
            if (seenIds.has(identity)) {
                return;
            }

            seenIds.add(identity);
            uniqueGoals.push(goal);
        });

        return uniqueGoals;
    }

    formatGoal(goal, normalizedStatus) {
        const progress = this.buildProgressState(goal, normalizedStatus);
        const targetState = this.buildTargetState(goal, normalizedStatus);
        const supportingMeta = [goal.serviceModality, goal.frequency, goal.priority].filter(Boolean).join(' • ');

        return {
            ...goal,
            name: goal.name || 'Untitled Goal',
            status: normalizedStatus,
            statusClass: this.getStatusClass(normalizedStatus),
            statusLabel: normalizedStatus,
            displayDescription: goal.objective || goal.description || 'No goal description has been added yet.',
            hasSupportingMeta: supportingMeta.length > 0,
            supportingMeta,
            hasStartDate: Boolean(goal.startDate),
            hasTargetDate: Boolean(goal.targetDate),
            formattedStartDate: this.formatDate(goal.startDate),
            formattedTargetDate: this.formatDate(goal.targetDate),
            dateRangeLabel: this.buildDateRange(goal.startDate, goal.targetDate),
            lastWorkedLabel: this.buildLastWorkedLabel(goal),
            hasLastWorkedLabel: Boolean(this.buildLastWorkedLabel(goal)),
            progressValue: progress.value,
            progressLabel: progress.label,
            progressAssistiveText: progress.assistiveText,
            targetBadgeLabel: targetState.badgeLabel,
            targetBadgeClass: targetState.badgeClass,
            isDueSoon: targetState.isDueSoon,
            isOverdue: targetState.isOverdue,
            cardClass: targetState.isOverdue ? 'goal-card goal-card_overdue' : 'goal-card'
        };
    }

    compareGoals(left, right) {
        if (left.isOverdue !== right.isOverdue) {
            return left.isOverdue ? -1 : 1;
        }

        if (left.hasTargetDate !== right.hasTargetDate) {
            return left.hasTargetDate ? -1 : 1;
        }

        const leftTarget = left.targetDate ? new Date(left.targetDate).getTime() : Number.MAX_SAFE_INTEGER;
        const rightTarget = right.targetDate ? new Date(right.targetDate).getTime() : Number.MAX_SAFE_INTEGER;
        if (leftTarget !== rightTarget) {
            return leftTarget - rightTarget;
        }

        return left.name.localeCompare(right.name);
    }

    buildProgressState(goal, normalizedStatus) {
        const numericProgress = Number(goal.currentProgress);
        const hasRecordedProgress = (goal.totalSessions || 0) > 0 && Number.isFinite(numericProgress);
        const value = hasRecordedProgress ? Math.max(0, Math.min(100, Math.round(numericProgress))) : 0;

        if (normalizedStatus === 'Completed') {
            return {
                value: 100,
                label: 'Completed',
                assistiveText: 'Goal completed'
            };
        }

        if (!hasRecordedProgress) {
            return {
                value: 0,
                label: 'No note progress recorded yet.',
                assistiveText: 'No goal progress has been captured in notes yet'
            };
        }

        return {
            value,
            label: value === 100
                ? 'Goal progress recorded as complete.'
                : goal.totalSessions > 1
                    ? 'Progress reflects the latest note updates.'
                    : 'Progress reflects the latest note update.',
            assistiveText: 'Goal progress captured from note activity'
        };
    }

    buildTargetState(goal, normalizedStatus) {
        if (normalizedStatus === 'Completed') {
            return {
                badgeLabel: 'Completed',
                badgeClass: 'goal-pill goal-pill_success',
                isDueSoon: false,
                isOverdue: false
            };
        }

        const today = this.startOfDay(new Date());
        const targetDate = goal.targetDate ? this.startOfDay(new Date(goal.targetDate)) : null;

        if (!targetDate || Number.isNaN(targetDate.getTime())) {
            return {
                badgeLabel: 'Dates Needed',
                badgeClass: 'goal-pill goal-pill_neutral',
                isDueSoon: false,
                isOverdue: false
            };
        }

        const daysUntilTarget = Math.round((targetDate.getTime() - today.getTime()) / DAY_IN_MS);
        const isOverdue = daysUntilTarget < 0;
        const isDueSoon = !isOverdue && daysUntilTarget <= DUE_SOON_DAYS;

        if (isOverdue) {
            return {
                badgeLabel: 'Overdue',
                badgeClass: 'goal-pill goal-pill_warning',
                isDueSoon,
                isOverdue
            };
        }

        if (daysUntilTarget === 0) {
            return {
                badgeLabel: 'Due Today',
                badgeClass: 'goal-pill goal-pill_attention',
                isDueSoon: true,
                isOverdue
            };
        }

        if (isDueSoon) {
            return {
                badgeLabel: 'Due Soon',
                badgeClass: 'goal-pill goal-pill_attention',
                isDueSoon,
                isOverdue
            };
        }

        return {
            badgeLabel: 'On Track',
            badgeClass: 'goal-pill goal-pill_neutral',
            isDueSoon,
            isOverdue
        };
    }

    buildDateRange(startDate, targetDate) {
        const parts = [];

        if (startDate) {
            parts.push(`Started ${this.formatDate(startDate)}`);
        }

        if (targetDate) {
            parts.push(`Target ${this.formatDate(targetDate)}`);
        }

        return parts.join(' • ');
    }

    buildLastWorkedLabel(goal) {
        const parts = [];
        const lastWorkedDate = this.formatDate(goal.lastWorkedOn);

        if (lastWorkedDate) {
            let label = `Last worked ${lastWorkedDate}`;
            if (goal.lastWorkedByName) {
                label += ` by ${goal.lastWorkedByName}`;
            }
            parts.push(label);
        }

        if ((goal.totalSessions || 0) > 0) {
            parts.push(goal.totalSessions === 1 ? '1 note update' : `${goal.totalSessions} note updates`);
        }

        return parts.join(' • ');
    }

    normalizeStatus(status) {
        return status && status.trim() ? status.trim() : 'Active';
    }

    isActiveStatus(status) {
        return !INACTIVE_STATUSES.has(status);
    }

    getStatusClass(status) {
        if (status === 'Completed') {
            return 'goal-pill goal-pill_success';
        }

        if (status === 'Cancelled') {
            return 'goal-pill goal-pill_warning';
        }

        return 'goal-pill goal-pill_active';
    }

    startOfDay(value) {
        const date = new Date(value);
        date.setHours(0, 0, 0, 0);
        return date;
    }

    formatDate(value) {
        if (!value) {
            return null;
        }

        try {
            const date = new Date(value);
            return date.toLocaleDateString('en-US', {
                month: 'short',
                day: 'numeric',
                year: 'numeric'
            });
        } catch {
            return value;
        }
    }

    reduceErrors(error) {
        if (!error) {
            return 'An unknown error occurred.';
        }

        if (Array.isArray(error.body)) {
            return error.body.map((item) => item.message).join(', ');
        }

        if (typeof error.body?.message === 'string') {
            return error.body.message;
        }

        if (typeof error.message === 'string') {
            return error.message;
        }

        return 'An unknown error occurred.';
    }
}