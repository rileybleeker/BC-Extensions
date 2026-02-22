// Planning Worksheet Visualizer - Chart.js rendering and explanation panel
(function () {
    'use strict';

    var chartInstance = null;
    var chartData = null;
    var explanationData = null;
    var showTracking = false;

    // --- HTML Structure ---
    function buildUI() {
        var container = document.getElementById('controlAddIn');
        if (!container) {
            container = document.createElement('div');
            container.id = 'controlAddIn';
            document.body.appendChild(container);
        }
        container.innerHTML =
            '<div id="visualizer-root">' +
            '  <div id="chart-toolbar">' +
            '    <div class="toolbar-group">' +
            '      <label class="toggle-label"><input type="checkbox" id="chkBefore" checked> Before Suggestions</label>' +
            '      <label class="toggle-label"><input type="checkbox" id="chkAfter" checked> After Suggestions</label>' +
            '    </div>' +
            '    <div class="toolbar-group">' +
            '      <label class="toggle-label"><input type="checkbox" id="chkExisting" checked> Existing Supply</label>' +
            '      <label class="toggle-label"><input type="checkbox" id="chkSuggested" checked> Suggested Supply</label>' +
            '      <label class="toggle-label"><input type="checkbox" id="chkDemand" checked> Demand</label>' +
            '      <label class="toggle-label"><input type="checkbox" id="chkPending" checked> Pending Req. Lines</label>' +
            '      <label class="toggle-label"><input type="checkbox" id="chkPlanComp" checked> Planning Components</label>' +
            '      <label class="toggle-label"><input type="checkbox" id="chkForecast" checked> Demand Forecast</label>' +
            '      <label class="toggle-label"><input type="checkbox" id="chkTracking"> Order Tracking</label>' +
            '    </div>' +
            '    <div class="toolbar-group">' +
            '      <label class="toggle-label">Horizon: ' +
            '        <select id="selHorizon">' +
            '          <option value="30">30 days</option>' +
            '          <option value="60">60 days</option>' +
            '          <option value="90" selected>90 days</option>' +
            '          <option value="180">180 days</option>' +
            '          <option value="365">1 year</option>' +
            '        </select>' +
            '      </label>' +
            '    </div>' +
            '  </div>' +
            '  <div id="chart-container"><canvas id="projectionChart"></canvas></div>' +
            '  <div id="explanation-panel"></div>' +
            '</div>';

        // Bind toggle events
        bindToggle('chkBefore', 0);
        bindToggle('chkAfter', 1);
        bindToggle('chkExisting', 2);
        bindToggle('chkDemand', 3);
        bindToggle('chkSuggested', 4);
        bindToggle('chkPending', 5);
        bindToggle('chkPlanComp', 6);
        bindToggle('chkForecast', 7);

        document.getElementById('chkTracking').addEventListener('change', function () {
            showTracking = this.checked;
            if (chartInstance) chartInstance.update();
        });

        document.getElementById('selHorizon').addEventListener('change', function () {
            Microsoft.Dynamics.NAV.InvokeExtensibilityMethod('OnHorizonChanged', [parseInt(this.value)]);
        });
    }

    function bindToggle(checkboxId, datasetIndex) {
        document.getElementById(checkboxId).addEventListener('change', function () {
            if (chartInstance) {
                chartInstance.setDatasetVisibility(datasetIndex, this.checked);
                chartInstance.update();
            }
        });
    }

    // --- Chart Rendering ---
    function renderChart(data) {
        chartData = data;
        var ctx = document.getElementById('projectionChart').getContext('2d');

        // Prepare projection data
        var beforeData = (data.projectionBefore || []).map(function (p) {
            return { x: p.date, y: p.balance };
        });
        var afterData = (data.projectionAfter || []).map(function (p) {
            return { x: p.date, y: p.balance };
        });

        // Prepare event scatter data
        var supplyPoints = [];
        var demandPoints = [];
        var suggestionPoints = [];
        var pendingReqPoints = [];
        var planningCompPoints = [];
        var forecastPoints = [];
        var eventLookup = {};

        (data.events || []).forEach(function (evt) {
            eventLookup[evt.entryNo] = evt;
            if (evt.type === 'Initial Inventory') return;
            var point = { x: evt.date, y: evt.balanceAfter, entryNo: evt.entryNo };
            if (evt.type === 'Demand Forecast') {
                forecastPoints.push(point);
            } else if (evt.type === 'Planning Component') {
                planningCompPoints.push(point);
            } else if (evt.type === 'Pending Requisition Line') {
                pendingReqPoints.push(point);
            } else if (evt.isSuggestion) {
                suggestionPoints.push(point);
            } else if (evt.isSupply) {
                supplyPoints.push(point);
            } else {
                demandPoints.push(point);
            }
        });

        var thresholds = data.thresholds || {};
        var safetyStock = thresholds.safetyStock || 0;
        var reorderPoint = thresholds.reorderPoint || 0;
        var maxInventory = thresholds.maxInventory || 0;

        // Build annotations
        var annotations = {};
        if (reorderPoint > 0) {
            annotations.reorderPointLine = {
                type: 'line',
                yMin: reorderPoint, yMax: reorderPoint,
                borderColor: 'rgba(255, 193, 7, 0.8)',
                borderWidth: 2, borderDash: [10, 5],
                label: { display: true, content: 'Reorder Point (' + reorderPoint + ')', position: 'start', backgroundColor: 'rgba(255,193,7,0.7)', font: { size: 11 } }
            };
        }
        if (safetyStock > 0) {
            annotations.safetyStockLine = {
                type: 'line',
                yMin: safetyStock, yMax: safetyStock,
                borderColor: 'rgba(220, 53, 69, 0.8)',
                borderWidth: 2, borderDash: [10, 5],
                label: { display: true, content: 'Safety Stock (' + safetyStock + ')', position: 'start', backgroundColor: 'rgba(220,53,69,0.7)', color: '#fff', font: { size: 11 } }
            };
            annotations.dangerZone = {
                type: 'box',
                yMin: 0, yMax: safetyStock,
                backgroundColor: 'rgba(220, 53, 69, 0.05)',
                borderWidth: 0
            };
        }
        if (reorderPoint > 0 && safetyStock > 0) {
            annotations.warningZone = {
                type: 'box',
                yMin: safetyStock, yMax: reorderPoint,
                backgroundColor: 'rgba(255, 193, 7, 0.05)',
                borderWidth: 0
            };
        }
        if (maxInventory > 0) {
            annotations.maxInventoryLine = {
                type: 'line',
                yMin: maxInventory, yMax: maxInventory,
                borderColor: 'rgba(40, 167, 69, 0.6)',
                borderWidth: 2, borderDash: [10, 5],
                label: { display: true, content: 'Max Inventory (' + maxInventory + ')', position: 'start', backgroundColor: 'rgba(40,167,69,0.7)', color: '#fff', font: { size: 11 } }
            };
        }

        if (chartInstance) {
            chartInstance.destroy();
        }

        chartInstance = new Chart(ctx, {
            type: 'line',
            data: {
                datasets: [
                    // Dataset 0: Before Suggestions
                    {
                        label: 'Before Suggestions',
                        data: beforeData,
                        stepped: 'before',
                        borderColor: 'rgba(100, 149, 237, 0.5)',
                        borderWidth: 2,
                        borderDash: [6, 4],
                        fill: false,
                        pointRadius: 0,
                        pointHitRadius: 0,
                        order: 3
                    },
                    // Dataset 1: After Suggestions
                    {
                        label: 'After Suggestions',
                        data: afterData,
                        stepped: 'before',
                        borderColor: 'rgba(30, 80, 200, 1)',
                        borderWidth: 2,
                        fill: {
                            target: 'origin',
                            above: 'rgba(30, 80, 200, 0.04)',
                            below: 'rgba(220, 53, 69, 0.08)'
                        },
                        segment: {
                            borderColor: function (ctx) {
                                var val = ctx.p1.parsed.y;
                                if (val < safetyStock) return 'rgba(220, 20, 20, 1)';
                                if (val < reorderPoint) return 'rgba(255, 165, 0, 1)';
                                return 'rgba(30, 80, 200, 1)';
                            }
                        },
                        pointRadius: 0,
                        pointHitRadius: 0,
                        order: 2
                    },
                    // Dataset 2: Supply Events
                    {
                        label: 'Existing Supply',
                        data: supplyPoints,
                        type: 'scatter',
                        pointStyle: 'triangle',
                        pointRadius: 8,
                        pointHoverRadius: 12,
                        backgroundColor: 'rgba(40, 167, 69, 0.8)',
                        borderColor: 'rgba(40, 167, 69, 1)',
                        borderWidth: 1,
                        order: 1
                    },
                    // Dataset 3: Demand Events
                    {
                        label: 'Demand',
                        data: demandPoints,
                        type: 'scatter',
                        pointStyle: 'triangle',
                        rotation: 180,
                        pointRadius: 8,
                        pointHoverRadius: 12,
                        backgroundColor: 'rgba(220, 53, 69, 0.8)',
                        borderColor: 'rgba(220, 53, 69, 1)',
                        borderWidth: 1,
                        order: 1
                    },
                    // Dataset 4: Suggested Supply (current worksheet)
                    {
                        label: 'Suggested Supply',
                        data: suggestionPoints,
                        type: 'scatter',
                        pointStyle: 'rectRot',
                        pointRadius: 10,
                        pointHoverRadius: 14,
                        backgroundColor: 'rgba(111, 66, 193, 0.8)',
                        borderColor: 'rgba(111, 66, 193, 1)',
                        borderWidth: 2,
                        order: 0
                    },
                    // Dataset 5: Pending Req. Lines (other worksheets)
                    {
                        label: 'Pending Req. Lines',
                        data: pendingReqPoints,
                        type: 'scatter',
                        pointStyle: 'rect',
                        pointRadius: 7,
                        pointHoverRadius: 11,
                        backgroundColor: 'rgba(23, 162, 184, 0.6)',
                        borderColor: 'rgba(23, 162, 184, 1)',
                        borderWidth: 2,
                        borderDash: [3, 2],
                        order: 0
                    },
                    // Dataset 6: Planning Components (dependent demand)
                    {
                        label: 'Planning Components',
                        data: planningCompPoints,
                        type: 'scatter',
                        pointStyle: 'crossRot',
                        rotation: 0,
                        pointRadius: 8,
                        pointHoverRadius: 12,
                        backgroundColor: 'rgba(255, 133, 27, 0.8)',
                        borderColor: 'rgba(255, 133, 27, 1)',
                        borderWidth: 2,
                        order: 0
                    },
                    // Dataset 7: Demand Forecast (informational, not in running totals)
                    {
                        label: 'Demand Forecast',
                        data: forecastPoints,
                        type: 'scatter',
                        pointStyle: 'star',
                        pointRadius: 10,
                        pointHoverRadius: 14,
                        backgroundColor: 'rgba(255, 215, 0, 0.7)',
                        borderColor: 'rgba(218, 165, 32, 1)',
                        borderWidth: 2,
                        order: 0
                    }
                ]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                interaction: {
                    mode: 'nearest',
                    intersect: true
                },
                onClick: function (evt, elements) {
                    if (elements.length === 0) return;
                    var el = elements[0];
                    var ds = chartInstance.data.datasets[el.datasetIndex];
                    var point = ds.data[el.index];
                    if (point && point.entryNo) {
                        var evtData = eventLookup[point.entryNo];
                        if (evtData && evtData.sourcePageId > 0) {
                            Microsoft.Dynamics.NAV.InvokeExtensibilityMethod('OnEventClicked', [
                                point.entryNo,
                                evtData.sourcePageId,
                                evtData.sourceDocNo || '',
                                evtData.sourceLineNo || 0
                            ]);
                        }
                    }
                },
                plugins: {
                    annotation: {
                        annotations: annotations
                    },
                    tooltip: {
                        callbacks: {
                            title: function (items) {
                                if (items.length === 0) return '';
                                return items[0].raw.x || items[0].label || '';
                            },
                            label: function (context) {
                                var ds = context.dataset;
                                var raw = context.raw;

                                // Projection lines
                                if (context.datasetIndex <= 1) {
                                    return ds.label + ': ' + formatQty(raw.y);
                                }

                                // Scatter points
                                if (raw.entryNo) {
                                    var evt = eventLookup[raw.entryNo];
                                    if (evt) {
                                        var lines = [evt.type + ': ' + formatQty(evt.qty)];
                                        if (evt.description) lines.push(evt.description);
                                        if (evt.actionMessage) lines.push('Action: ' + evt.actionMessage);
                                        lines.push('Projected Inventory: ' + formatQty(evt.balanceAfter));
                                        return lines;
                                    }
                                }
                                return ds.label + ': ' + formatQty(raw.y);
                            }
                        }
                    },
                    legend: {
                        display: true,
                        position: 'bottom',
                        labels: { usePointStyle: true, padding: 15 }
                    }
                },
                scales: {
                    x: {
                        type: 'category',
                        title: { display: true, text: 'Date', font: { size: 13 } },
                        ticks: { maxRotation: 45, autoSkip: true, maxTicksLimit: 20 }
                    },
                    y: {
                        title: { display: true, text: 'Inventory Quantity', font: { size: 13 } },
                        beginAtZero: false
                    }
                }
            },
            plugins: [trackingLinesPlugin]
        });
    }

    // Custom plugin to draw order tracking lines
    var trackingLinesPlugin = {
        id: 'trackingLines',
        afterDatasetsDraw: function (chart) {
            if (!showTracking || !chartData || !chartData.trackingPairs) return;
            var ctx = chart.ctx;
            var meta2 = chart.getDatasetMeta(2); // supply
            var meta3 = chart.getDatasetMeta(3); // demand
            var meta4 = chart.getDatasetMeta(4); // suggestions
            var meta5 = chart.getDatasetMeta(5); // pending req lines
            var meta6 = chart.getDatasetMeta(6); // planning components
            var meta7 = chart.getDatasetMeta(7); // demand forecast

            chartData.trackingPairs.forEach(function (pair) {
                var supplyPt = findPointPixel(chart, pair.supplyEntryNo, [meta2, meta4, meta5]);
                var demandPt = findPointPixel(chart, pair.demandEntryNo, [meta3, meta6, meta7]);

                if (supplyPt && demandPt) {
                    ctx.save();
                    ctx.beginPath();
                    ctx.setLineDash([3, 3]);
                    ctx.strokeStyle = 'rgba(128, 128, 128, 0.4)';
                    ctx.lineWidth = 1;
                    ctx.moveTo(supplyPt.x, supplyPt.y);
                    ctx.lineTo(demandPt.x, demandPt.y);
                    ctx.stroke();
                    ctx.restore();
                }
            });
        }
    };

    function findPointPixel(chart, entryNo, metas) {
        for (var m = 0; m < metas.length; m++) {
            var meta = metas[m];
            if (!meta.visible) continue;
            var ds = chart.data.datasets[meta.index];
            for (var i = 0; i < ds.data.length; i++) {
                if (ds.data[i].entryNo === entryNo) {
                    var el = meta.data[i];
                    if (el) return { x: el.x, y: el.y };
                }
            }
        }
        return null;
    }

    function formatQty(val) {
        if (val === null || val === undefined) return '0';
        return val.toLocaleString(undefined, { minimumFractionDigits: 0, maximumFractionDigits: 2 });
    }

    // --- Explanation Panel ---
    function renderExplanations(data) {
        explanationData = data;
        var panel = document.getElementById('explanation-panel');
        if (!panel) return;

        var explanations = data.explanations || [];
        if (explanations.length === 0) {
            panel.innerHTML = '<div class="no-explanations">No planning suggestions for this item.</div>';
            return;
        }

        var html = '<h3 class="panel-title">Planning Suggestions Explained</h3>';
        explanations.forEach(function (expl) {
            var severityClass = 'severity-' + expl.severity;
            var actionClass = 'action-' + (expl.action || '').toLowerCase().replace(/[^a-z]/g, '');
            var severityLabel = expl.severity === 3 ? 'Critical' : (expl.severity === 2 ? 'Warning' : 'Info');

            html +=
                '<div class="explanation-card ' + severityClass + '" data-reqlineno="' + expl.reqLineNo + '">' +
                '  <div class="explanation-header">' +
                '    <span class="action-badge ' + actionClass + '">' + escapeHtml(expl.action) + '</span>' +
                '    <span class="severity-badge ' + severityClass + '">' + severityLabel + '</span>' +
                '    <span class="expl-qty">' + formatQty(expl.qty) + ' units</span>' +
                '    <span class="expl-date">Due: ' + expl.dueDate + '</span>' +
                '    <span class="expl-policy">' + escapeHtml(expl.reorderingPolicy) + '</span>' +
                '  </div>' +
                '  <div class="explanation-summary">' + escapeHtml(expl.summary) + '</div>' +
                '  <div class="explanation-detail collapsed">' +
                '    <p><strong>Reason:</strong> ' + escapeHtml(expl.why) + '</p>' +
                '    <p><strong>Impact:</strong> ' + escapeHtml(expl.impact) + '</p>' +
                '  </div>' +
                '  <button class="expand-btn" onclick="window._toggleDetail(this)">Show Details</button>' +
                '</div>';
        });

        panel.innerHTML = html;

        // Bind card click for drill-down
        var cards = panel.querySelectorAll('.explanation-card');
        cards.forEach(function (card) {
            card.addEventListener('dblclick', function () {
                var reqLineNo = parseInt(this.getAttribute('data-reqlineno'));
                if (reqLineNo) {
                    Microsoft.Dynamics.NAV.InvokeExtensibilityMethod('OnExplanationClicked', [reqLineNo]);
                }
            });
        });
    }

    window._toggleDetail = function (btn) {
        var detail = btn.previousElementSibling;
        if (detail.classList.contains('collapsed')) {
            detail.classList.remove('collapsed');
            btn.textContent = 'Hide Details';
        } else {
            detail.classList.add('collapsed');
            btn.textContent = 'Show Details';
        }
    };

    function escapeHtml(str) {
        if (!str) return '';
        return str.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
    }

    // --- Public API (called from AL) ---
    window.LoadChartData = function (jsonString) {
        try {
            var data = JSON.parse(jsonString);
            buildUI();
            renderChart(data);
        } catch (e) {
            console.error('LoadChartData error:', e);
        }
    };

    window.LoadExplanations = function (jsonString) {
        try {
            var data = JSON.parse(jsonString);
            renderExplanations(data);
        } catch (e) {
            console.error('LoadExplanations error:', e);
        }
    };

    window.UpdateVisibility = function (showExisting, showSuggested, showDemand) {
        if (!chartInstance) return;
        chartInstance.setDatasetVisibility(2, showExisting);
        chartInstance.setDatasetVisibility(3, showDemand);
        chartInstance.setDatasetVisibility(4, showSuggested);
        chartInstance.update();
    };

    window.ToggleProjection = function (showBefore, showAfter) {
        if (!chartInstance) return;
        chartInstance.setDatasetVisibility(0, showBefore);
        chartInstance.setDatasetVisibility(1, showAfter);
        chartInstance.update();
    };

    window.HighlightEvent = function (entryNo) {
        // Future: highlight a specific event on the chart
    };

    window.ShowTrackingLines = function (visible) {
        showTracking = visible;
        var chk = document.getElementById('chkTracking');
        if (chk) chk.checked = visible;
        if (chartInstance) chartInstance.update();
    };

})();
