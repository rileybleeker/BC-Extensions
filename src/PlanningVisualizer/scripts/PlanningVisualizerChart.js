// Planning Worksheet Visualizer - Chart.js rendering and explanation panel
(function () {
    'use strict';

    var chartInstance = null;
    var chartData = null;
    var explanationData = null;
    var showTracking = false;
    var showCoverage = false;

    // Dataset index constants
    var DS_PAB = 0;              // Projected Available Balance
    var DS_FORECASTED = 1;       // Forecasted Projected Inventory
    var DS_SUGGESTED = 2;        // Suggested Projected Inventory
    var DS_SUPPLY = 3;           // Existing Supply scatter
    var DS_DEMAND = 4;           // Demand scatter
    var DS_SUGG_SUPPLY = 5;      // Suggested Supply scatter
    var DS_PENDING = 6;          // Pending Req. Lines scatter
    var DS_PLAN_COMP = 7;        // Planning Components scatter
    var DS_FORECAST = 8;         // Demand Forecast scatter

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
            '      <label class="toggle-label"><input type="checkbox" id="chkPAB"> Projected Available Balance</label>' +
            '      <label class="toggle-label"><input type="checkbox" id="chkForecasted"> Forecasted Projected Inventory</label>' +
            '      <label class="toggle-label"><input type="checkbox" id="chkSuggestedLine" checked> Suggested Projected Inventory</label>' +
            '    </div>' +
            '    <div class="toolbar-group">' +
            '      <label class="toggle-label"><input type="checkbox" id="chkExisting" checked> Existing Supply</label>' +
            '      <label class="toggle-label"><input type="checkbox" id="chkSuggested" checked> Suggested Supply</label>' +
            '      <label class="toggle-label"><input type="checkbox" id="chkDemand" checked> Demand</label>' +
            '      <label class="toggle-label"><input type="checkbox" id="chkPending" checked> Pending Req. Lines</label>' +
            '      <label class="toggle-label"><input type="checkbox" id="chkPlanComp" checked> Planning Components</label>' +
            '      <label class="toggle-label"><input type="checkbox" id="chkForecast" checked> Demand Forecast</label>' +
            '      <label class="toggle-label"><input type="checkbox" id="chkTracking"> Order Tracking</label>' +
            '      <label class="toggle-label"><input type="checkbox" id="chkCoverage"> Coverage Bars</label>' +
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

        // Bind toggle events for projection lines
        bindToggle('chkPAB', DS_PAB);
        bindToggle('chkForecasted', DS_FORECASTED);
        bindToggle('chkSuggestedLine', DS_SUGGESTED);

        // Bind toggle events for scatter datasets
        bindToggle('chkExisting', DS_SUPPLY);
        bindToggle('chkDemand', DS_DEMAND);
        bindToggle('chkSuggested', DS_SUGG_SUPPLY);
        bindToggle('chkPending', DS_PENDING);
        bindToggle('chkPlanComp', DS_PLAN_COMP);
        bindToggle('chkForecast', DS_FORECAST);

        document.getElementById('chkTracking').addEventListener('change', function () {
            showTracking = this.checked;
            if (chartInstance) chartInstance.update();
        });

        document.getElementById('chkCoverage').addEventListener('change', function () {
            showCoverage = this.checked;
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
        var pabData = (data.projectionBefore || []).map(function (p) {
            return { x: p.date, y: p.balance };
        });
        var forecastedData = (data.projectionForecasted || []).map(function (p) {
            return { x: p.date, y: p.balance };
        });
        var suggestedData = (data.projectionAfter || []).map(function (p) {
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
                    // Dataset 0 (DS_PAB): Projected Available Balance
                    {
                        label: 'Projected Available Balance',
                        data: pabData,
                        stepped: 'before',
                        borderColor: 'rgba(100, 149, 237, 0.5)',
                        borderWidth: 2,
                        borderDash: [6, 4],
                        fill: false,
                        pointRadius: 0,
                        pointHitRadius: 0,
                        order: 4,
                        hidden: true
                    },
                    // Dataset 1 (DS_FORECASTED): Forecasted Projected Inventory
                    {
                        label: 'Forecasted Projected Inventory',
                        data: forecastedData,
                        stepped: 'before',
                        borderColor: 'rgba(218, 165, 32, 0.7)',
                        borderWidth: 2,
                        borderDash: [4, 3],
                        fill: false,
                        pointRadius: 0,
                        pointHitRadius: 0,
                        order: 3,
                        hidden: true
                    },
                    // Dataset 2 (DS_SUGGESTED): Suggested Projected Inventory
                    {
                        label: 'Suggested Projected Inventory',
                        data: suggestedData,
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
                    // Dataset 3 (DS_SUPPLY): Existing Supply Events
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
                    // Dataset 4 (DS_DEMAND): Demand Events
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
                    // Dataset 5 (DS_SUGG_SUPPLY): Suggested Supply (current worksheet)
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
                    // Dataset 6 (DS_PENDING): Pending Req. Lines (other worksheets)
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
                    // Dataset 7 (DS_PLAN_COMP): Planning Components (dependent demand)
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
                    // Dataset 8 (DS_FORECAST): Demand Forecast (informational)
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

                                // Projection lines (datasets 0-2)
                                if (context.datasetIndex <= DS_SUGGESTED) {
                                    return ds.label + ': ' + formatQty(raw.y);
                                }

                                // Scatter points
                                if (raw.entryNo) {
                                    var evt = eventLookup[raw.entryNo];
                                    if (evt) {
                                        var lines = [evt.type + ': ' + formatQty(evt.qty)];
                                        if (evt.description) lines.push(evt.description);
                                        if (evt.actionMessage) lines.push('Action: ' + evt.actionMessage);
                                        lines.push('Suggested Projected Inventory: ' + formatQty(evt.balanceAfter));
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
                        title: { display: true, text: 'Suggested Projected Inventory', font: { size: 13 } },
                        beginAtZero: false
                    }
                }
            },
            plugins: [trackingLinesPlugin, coverageBarsPlugin]
        });
    }

    // Custom plugin to draw order tracking lines
    var trackingLinesPlugin = {
        id: 'trackingLines',
        afterDatasetsDraw: function (chart) {
            if (!showTracking || !chartData || !chartData.trackingPairs) return;
            var ctx = chart.ctx;
            var metaSupply = chart.getDatasetMeta(DS_SUPPLY);
            var metaDemand = chart.getDatasetMeta(DS_DEMAND);
            var metaSuggSupply = chart.getDatasetMeta(DS_SUGG_SUPPLY);
            var metaPending = chart.getDatasetMeta(DS_PENDING);
            var metaPlanComp = chart.getDatasetMeta(DS_PLAN_COMP);
            var metaForecast = chart.getDatasetMeta(DS_FORECAST);

            chartData.trackingPairs.forEach(function (pair) {
                var supplyPt = findPointPixel(chart, pair.supplyEntryNo, [metaSupply, metaSuggSupply, metaPending]);
                var demandPt = findPointPixel(chart, pair.demandEntryNo, [metaDemand, metaPlanComp, metaForecast]);

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

    // Custom plugin to draw coverage bars for planning suggestions
    var coverageBarsPlugin = {
        id: 'coverageBars',
        afterDatasetsDraw: function (chart) {
            if (!showCoverage || !chartData || !chartData.coverageBars || chartData.coverageBars.length === 0) return;

            var ctx = chart.ctx;
            var xScale = chart.scales.x;
            var chartArea = chart.chartArea;
            var barHeight = 14;
            var innerGap = 2;    // gap between order bar and coverage bar within same order
            var orderGap = 6;    // gap between different orders
            var rowHeight = barHeight * 2 + innerGap + orderGap;
            var baseY = chartArea.bottom - 8;

            chartData.coverageBars.forEach(function (bar, index) {
                var coverageStartPixel = getPixelForDate(xScale, bar.startDate);
                var coverageEndPixel = getPixelForDate(xScale, bar.endDate || bar.startDate);

                if (coverageStartPixel === null || coverageEndPixel === null) return;
                if (coverageEndPixel - coverageStartPixel < 8) coverageEndPixel = coverageStartPixel + 8;

                // Coverage bar position (bottom of the pair)
                var coverageY = baseY - (index * rowHeight);
                // Order timeline bar position (above coverage bar)
                var orderY = coverageY - barHeight - innerGap;

                ctx.save();

                // --- Order Timeline Bar (teal) ---
                if (bar.orderStartDate || bar.orderEndDate) {
                    var orderStartPixel = getPixelForDate(xScale, bar.orderStartDate || bar.startDate);
                    var orderEndPixel = getPixelForDate(xScale, bar.orderEndDate || bar.startDate);

                    if (orderStartPixel !== null && orderEndPixel !== null) {
                        if (orderEndPixel - orderStartPixel < 8) orderEndPixel = orderStartPixel + 8;

                        // Draw order timeline bar
                        ctx.fillStyle = 'rgba(23, 162, 184, 0.12)';
                        ctx.strokeStyle = 'rgba(23, 162, 184, 0.5)';
                        ctx.lineWidth = 1;
                        drawRoundedRect(ctx, orderStartPixel, orderY, orderEndPixel - orderStartPixel, barHeight, 3);
                        ctx.fill();
                        ctx.stroke();

                        // Draw start marker (circle)
                        ctx.fillStyle = 'rgba(23, 162, 184, 0.8)';
                        ctx.beginPath();
                        ctx.arc(orderStartPixel + 3, orderY + barHeight / 2, 3, 0, 2 * Math.PI);
                        ctx.fill();

                        // Draw end marker (circle)
                        ctx.beginPath();
                        ctx.arc(orderEndPixel - 3, orderY + barHeight / 2, 3, 0, 2 * Math.PI);
                        ctx.fill();

                        // Draw label
                        ctx.fillStyle = 'rgba(23, 162, 184, 0.9)';
                        ctx.font = '10px sans-serif';
                        ctx.textBaseline = 'middle';
                        var orderLabel = 'Order: ' + (bar.orderStartDate || '') + ' \u2192 ' + (bar.orderEndDate || '');
                        var orderTextWidth = ctx.measureText(orderLabel).width;
                        var orderBarWidth = orderEndPixel - orderStartPixel;
                        if (orderTextWidth + 16 < orderBarWidth) {
                            ctx.fillText(orderLabel, orderStartPixel + 10, orderY + barHeight / 2);
                        }
                    }
                }

                // --- Coverage Bar (purple) ---
                // Draw main bar (rounded rectangle)
                ctx.fillStyle = 'rgba(111, 66, 193, 0.12)';
                ctx.strokeStyle = 'rgba(111, 66, 193, 0.5)';
                ctx.lineWidth = 1;
                drawRoundedRect(ctx, coverageStartPixel, coverageY, coverageEndPixel - coverageStartPixel, barHeight, 3);
                ctx.fill();
                ctx.stroke();

                // Draw demand tick marks within the bar
                (bar.trackedDemand || []).forEach(function (demand) {
                    var demandPixel = getPixelForDate(xScale, demand.date);
                    if (demandPixel !== null && demandPixel > coverageStartPixel + 2 && demandPixel < coverageEndPixel - 2) {
                        ctx.beginPath();
                        ctx.strokeStyle = 'rgba(220, 53, 69, 0.5)';
                        ctx.lineWidth = 1;
                        ctx.moveTo(demandPixel, coverageY + 2);
                        ctx.lineTo(demandPixel, coverageY + barHeight - 2);
                        ctx.stroke();
                    }
                });

                // Draw supply diamond at start
                ctx.fillStyle = 'rgba(111, 66, 193, 0.8)';
                ctx.beginPath();
                var d = 4;
                var midY = coverageY + barHeight / 2;
                ctx.moveTo(coverageStartPixel, midY - d);
                ctx.lineTo(coverageStartPixel + d, midY);
                ctx.lineTo(coverageStartPixel, midY + d);
                ctx.lineTo(coverageStartPixel - d, midY);
                ctx.closePath();
                ctx.fill();

                // Draw label
                ctx.fillStyle = 'rgba(111, 66, 193, 0.9)';
                ctx.font = '10px sans-serif';
                ctx.textBaseline = 'middle';
                var labelText = formatQty(bar.supplyQty) + ' units';
                var textWidth = ctx.measureText(labelText).width;
                var barWidth = coverageEndPixel - coverageStartPixel;
                if (textWidth + 16 < barWidth) {
                    ctx.fillText(labelText, coverageStartPixel + 10, midY);
                }

                ctx.restore();
            });
        },
        afterEvent: function (chart, args) {
            if (!showCoverage || !chartData || !chartData.coverageBars) return;
            if (args.event.type !== 'mousemove') return;

            var xScale = chart.scales.x;
            var chartArea = chart.chartArea;
            var mouseX = args.event.x;
            var mouseY = args.event.y;
            var barHeight = 14;
            var innerGap = 2;
            var orderGap = 6;
            var rowHeight = barHeight * 2 + innerGap + orderGap;
            var baseY = chartArea.bottom - 8;

            var hoveredBar = null;
            chartData.coverageBars.forEach(function (bar, index) {
                var coverageY = baseY - (index * rowHeight);
                var orderY = coverageY - barHeight - innerGap;

                // Hit-test coverage bar
                var startPixel = getPixelForDate(xScale, bar.startDate);
                var endPixel = getPixelForDate(xScale, bar.endDate || bar.startDate);
                if (startPixel !== null && endPixel !== null) {
                    if (endPixel - startPixel < 8) endPixel = startPixel + 8;
                    if (mouseX >= startPixel && mouseX <= endPixel &&
                        mouseY >= coverageY && mouseY <= coverageY + barHeight) {
                        hoveredBar = bar;
                    }
                }

                // Hit-test order timeline bar
                if (!hoveredBar && (bar.orderStartDate || bar.orderEndDate)) {
                    var oStartPixel = getPixelForDate(xScale, bar.orderStartDate || bar.startDate);
                    var oEndPixel = getPixelForDate(xScale, bar.orderEndDate || bar.startDate);
                    if (oStartPixel !== null && oEndPixel !== null) {
                        if (oEndPixel - oStartPixel < 8) oEndPixel = oStartPixel + 8;
                        if (mouseX >= oStartPixel && mouseX <= oEndPixel &&
                            mouseY >= orderY && mouseY <= orderY + barHeight) {
                            hoveredBar = bar;
                        }
                    }
                }
            });

            var tooltipEl = document.getElementById('coverage-tooltip');
            if (hoveredBar) {
                if (!tooltipEl) {
                    tooltipEl = document.createElement('div');
                    tooltipEl.id = 'coverage-tooltip';
                    tooltipEl.className = 'coverage-tooltip';
                    document.getElementById('chart-container').appendChild(tooltipEl);
                }
                var html = '<strong>Coverage: ' + formatQty(hoveredBar.supplyQty) +
                    ' units (' + escapeHtml(hoveredBar.actionMessage) + ')</strong><br>';

                if (hoveredBar.orderStartDate || hoveredBar.orderEndDate) {
                    html += '<span class="coverage-dates">Order: ' +
                        (hoveredBar.orderStartDate || '?') + ' \u2192 ' +
                        (hoveredBar.orderEndDate || '?') + '</span><br>';
                }

                html += '<span class="coverage-dates">Covers demand: ' + hoveredBar.startDate +
                    ' \u2192 ' + (hoveredBar.endDate || hoveredBar.startDate) + '</span>';

                if (hoveredBar.trackedDemand && hoveredBar.trackedDemand.length > 0) {
                    html += '<div class="coverage-section"><em>Tracked Demand:</em>';
                    hoveredBar.trackedDemand.forEach(function (dd) {
                        html += '<div class="coverage-line">\u2022 ' + dd.date +
                            ': ' + formatQty(dd.qty) + ' \u2014 ' + escapeHtml(dd.source) + '</div>';
                    });
                    html += '</div>';
                }
                if (hoveredBar.untrackedElements && hoveredBar.untrackedElements.length > 0) {
                    html += '<div class="coverage-section"><em>Untracked:</em>';
                    hoveredBar.untrackedElements.forEach(function (u) {
                        html += '<div class="coverage-line">\u2022 ' + escapeHtml(u.source) +
                            ': ' + formatQty(u.qty) + '</div>';
                    });
                    html += '</div>';
                }

                tooltipEl.innerHTML = html;
                tooltipEl.style.display = 'block';
                tooltipEl.style.left = (mouseX + 15) + 'px';
                tooltipEl.style.top = (mouseY - 10) + 'px';
            } else if (tooltipEl) {
                tooltipEl.style.display = 'none';
            }
        }
    };

    function drawRoundedRect(ctx, x, y, w, h, r) {
        ctx.beginPath();
        ctx.moveTo(x + r, y);
        ctx.lineTo(x + w - r, y);
        ctx.arcTo(x + w, y, x + w, y + r, r);
        ctx.lineTo(x + w, y + h - r);
        ctx.arcTo(x + w, y + h, x + w - r, y + h, r);
        ctx.lineTo(x + r, y + h);
        ctx.arcTo(x, y + h, x, y + h - r, r);
        ctx.lineTo(x, y + r);
        ctx.arcTo(x, y, x + r, y, r);
        ctx.closePath();
    }

    function getPixelForDate(xScale, dateStr) {
        if (!dateStr) return null;
        // Chart.js 4.x category scale: try direct label lookup
        var labels = xScale.getLabels();
        var idx = labels.indexOf(dateStr);
        if (idx !== -1) {
            return xScale.getPixelForValue(idx);
        }
        // Interpolate between nearest known dates
        return interpolatePixelForDate(xScale, labels, dateStr);
    }

    function interpolatePixelForDate(xScale, labels, dateStr) {
        var targetTime = new Date(dateStr).getTime();
        if (isNaN(targetTime)) return null;
        if (labels.length === 0) return null;

        var prevIdx = -1, nextIdx = -1;
        var prevTime = -Infinity, nextTime = Infinity;

        for (var i = 0; i < labels.length; i++) {
            var t = new Date(labels[i]).getTime();
            if (isNaN(t)) continue;
            if (t <= targetTime && t > prevTime) { prevIdx = i; prevTime = t; }
            if (t >= targetTime && t < nextTime) { nextIdx = i; nextTime = t; }
        }

        if (prevIdx !== -1 && nextIdx !== -1 && prevIdx !== nextIdx) {
            var ratio = (targetTime - prevTime) / (nextTime - prevTime);
            return xScale.getPixelForValue(prevIdx) + ratio * (xScale.getPixelForValue(nextIdx) - xScale.getPixelForValue(prevIdx));
        }
        if (prevIdx !== -1) return xScale.getPixelForValue(prevIdx);
        if (nextIdx !== -1) return xScale.getPixelForValue(nextIdx);
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
        chartInstance.setDatasetVisibility(DS_SUPPLY, showExisting);
        chartInstance.setDatasetVisibility(DS_DEMAND, showDemand);
        chartInstance.setDatasetVisibility(DS_SUGG_SUPPLY, showSuggested);
        chartInstance.update();
    };

    window.ToggleProjection = function (showBefore, showAfter) {
        if (!chartInstance) return;
        chartInstance.setDatasetVisibility(DS_PAB, showBefore);
        chartInstance.setDatasetVisibility(DS_SUGGESTED, showAfter);
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

    window.ShowCoverageBars = function (visible) {
        showCoverage = visible;
        var chk = document.getElementById('chkCoverage');
        if (chk) chk.checked = visible;
        if (chartInstance) chartInstance.update();
    };

})();
