import { resolve } from 'c/cmsResourceResolver';

/**
 * Transform product search API response data into display-data.
 *
 * @param {ConnectApi.ProductSummaryPage} data
 * @param {string} cardContentMapping
 */
export function transformData(data, cardContentMapping) {
    const {total = 0, products = [],
    } = data || {};

    return {
        total,
        /* Product list normalization */
        layoutData: products.map(
            ({ id, name, defaultImage, fields, prices }) => {
                defaultImage = defaultImage || {};
                const { unitPrice: negotiatedPrice, listPrice: listingPrice } =
                    prices || {};

                return {
                    id,
                    name,
                    fields: normalizedCardContentMapping(cardContentMapping)
                        .map((mapFieldName) => ({
                            name: mapFieldName,
                            value:
                                (fields[mapFieldName]) || ''
                        }))
                        .filter(({ value }) => !!value),
                    image: {
                        url: resolve(defaultImage.url),
                        title: defaultImage.title || '',
                        alternateText: defaultImage.alternateText || ''
                    },                    
                    allfields: fields,
                    prices: {
                        listingPrice,
                        negotiatedPrice
                                        }
                };
            }
        ).reverse()
    };
}

/**
 * Gets the normalized card content mapping fields.
 * @param {string} cardContentMapping comma separated fields
 * @returns {string[]}
 */
export function normalizedCardContentMapping(cardContentMapping) {
    return (cardContentMapping || 'Name').split(',');
}