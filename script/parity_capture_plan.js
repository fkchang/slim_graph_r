'use strict';

function reviewCapturePlan(scrollRegions) {
  const wideRegionIndices = scrollRegions
    .filter((region) => region.scroll_width > region.client_width)
    .map((region) => region.index);
  return wideRegionIndices.length === 0
    ? { mode: 'full-page', wide_region_indices: [] }
    : { mode: 'expanded-scroll-regions', wide_region_indices: wideRegionIndices };
}

module.exports = { reviewCapturePlan };
