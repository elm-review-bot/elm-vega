port module GalleryDist exposing (elmToJS)

import Html exposing (Html, div, pre)
import Html.Attributes exposing (id)
import Json.Encode
import Platform
import Vega exposing (..)


-- NOTE: All data sources in these examples originally provided at
-- https://vega.github.io/vega-datasets/
-- The examples themselves reproduce those at https://vega.github.io/vega/examples/


histo1 : Spec
histo1 =
    let
        ds =
            dataSource
                [ data "points" [ daUrl "https://vega.github.io/vega/data/normal-2d.json" ]
                , data "binned" [ daSource "points" ]
                    |> transform
                        [ trBin (field "u")
                            (nums [ -1, 1 ])
                            [ bnAnchor (numSignal "binOffset")
                            , bnStep (numSignal "binStep")
                            , bnNice false
                            ]
                        , trAggregate
                            [ agKey (field "bin0")
                            , agGroupBy [ field "bin0", field "bin1" ]
                            , agOps [ Count ]
                            , agAs [ "count" ]
                            ]
                        ]
                ]

        si =
            signals
                << signal "binOffset"
                    [ siValue (vNum 0)
                    , siBind (iRange [ inMin -0.1, inMax 0.1 ])
                    ]
                << signal "binStep"
                    [ siValue (vNum 0.1)
                    , siBind (iRange [ inMin -0.001, inMax 0.4, inStep 0.001 ])
                    ]

        sc =
            scales
                << scale "xScale"
                    [ scType ScLinear
                    , scRange RaWidth
                    , scDomain (doNums (nums [ -1, 1 ]))
                    ]
                << scale "yScale"
                    [ scType ScLinear
                    , scRange RaHeight
                    , scRound true
                    , scDomain (doData [ daDataset "binned", daField (field "count") ])
                    , scZero true
                    , scNice NTrue
                    ]

        ax =
            axes
                << axis "xScale" SBottom [ axZIndex (num 1) ]
                << axis "yScale" SLeft [ axTickCount (num 5), axZIndex (num 1) ]

        mk =
            marks
                << mark Rect
                    [ mFrom [ srData (str "binned") ]
                    , mEncode
                        [ enUpdate
                            [ maX [ vScale "xScale", vField (field "bin0") ]
                            , maX2 [ vScale "xScale", vField (field "bin1"), vOffset (vSignal "binStep > 0.02 ? -0.5 : 0") ]
                            , maY [ vScale "yScale", vField (field "count") ]
                            , maY2 [ vScale "yScale", vNum 0 ]
                            , maFill [ vStr "steelblue" ]
                            ]
                        , enHover [ maFill [ vStr "firebrick" ] ]
                        ]
                    ]
                << mark Rect
                    [ mFrom [ srData (str "points") ]
                    , mEncode
                        [ enEnter
                            [ maX [ vScale "xScale", vField (field "u") ]
                            , maWidth [ vNum 1 ]
                            , maY [ vNum 25, vOffset (vSignal "height") ]
                            , maHeight [ vNum 5 ]
                            , maFill [ vStr "#steelblue" ]
                            , maFillOpacity [ vNum 0.4 ]
                            ]
                        ]
                    ]
    in
    toVega
        [ width 500, height 100, padding 5, ds, si [], sc [], ax [], mk [] ]


histo2 : Spec
histo2 =
    let
        ds =
            dataSource
                [ data "table" [ daUrl "https://vega.github.io/vega/data/movies.json" ]
                    |> transform
                        [ trExtentAsSignal (field "IMDB_Rating") "extent"
                        , trBin (field "IMDB_Rating")
                            (numSignal "extent")
                            [ bnSignal "bins"
                            , bnMaxBins (numSignal "maxBins")
                            ]
                        ]
                , data "counts" [ daSource "table" ]
                    |> transform
                        [ trFilter (expr "datum['IMDB_Rating'] != null")
                        , trAggregate [ agGroupBy [ field "bin0", field "bin1" ] ]
                        ]
                , data "nulls" [ daSource "table" ]
                    |> transform
                        [ trFilter (expr "datum['IMDB_Rating'] == null")
                        , trAggregate []
                        ]
                ]

        si =
            signals
                << signal "maxBins" [ siValue (vNum 10), siBind (iSelect [ inOptions (vNums [ 5, 10, 20 ]) ]) ]
                << signal "binDomain" [ siUpdate "sequence(bins.start, bins.stop + bins.step, bins.step)" ]
                << signal "nullGap" [ siValue (vNum 10) ]
                << signal "barStep" [ siUpdate "(width - nullGap) / binDomain.length" ]

        sc =
            scales
                << scale "xScale"
                    [ scType ScBinLinear
                    , scRange (raValues [ vSignal "barStep + nullGap", vSignal "width" ])
                    , scDomain (doNums (numSignal "binDomain"))
                    , scRound true
                    ]
                << scale "xScaleNull"
                    [ scType ScBand
                    , scRange (raValues [ vNum 0, vSignal "barStep" ])
                    , scRound true
                    , scDomain (doStrs (strs [ "null" ]))
                    ]
                << scale "yScale"
                    [ scType ScLinear
                    , scRange RaHeight
                    , scRound true
                    , scNice NTrue
                    , scDomain
                        (doData
                            [ daReferences
                                [ [ daDataset "counts", daField (field "count") ]
                                , [ daDataset "nulls", daField (field "count") ]
                                ]
                            ]
                        )
                    ]

        ax =
            axes
                << axis "xScale" SBottom [ axTickCount (num 10) ]
                << axis "xScaleNull" SBottom []
                << axis "yScale" SLeft [ axTickCount (num 5), axOffset (vNum 5) ]

        mk =
            marks
                << mark Rect
                    [ mFrom [ srData (str "counts") ]
                    , mEncode
                        [ enUpdate
                            [ maX [ vScale "xScale", vField (field "bin0"), vOffset (vNum 1) ]
                            , maX2 [ vScale "xScale", vField (field "bin1") ]
                            , maY [ vScale "yScale", vField (field "count") ]
                            , maY2 [ vScale "yScale", vNum 0 ]
                            , maFill [ vStr "steelblue" ]
                            ]
                        , enHover [ maFill [ vStr "firebrick" ] ]
                        ]
                    ]
                << mark Rect
                    [ mFrom [ srData (str "nulls") ]
                    , mEncode
                        [ enUpdate
                            [ maX [ vScale "xScaleNull", vNull, vOffset (vNum 1) ]
                            , maX2 [ vScale "xScaleNull", vBand (num 1) ]
                            , maY [ vScale "yScale", vField (field "count") ]
                            , maY2 [ vScale "yScale", vNum 0 ]
                            , maFill [ vStr "#aaa" ]
                            ]
                        , enHover [ maFill [ vStr "firebrick" ] ]
                        ]
                    ]
    in
    toVega
        [ width 500, height 200, padding 5, autosize [ AFit, AResize ], ds, si [], sc [], ax [], mk [] ]


density1 : Spec
density1 =
    let
        ds =
            dataSource
                [ data "points" [ daUrl "https://vega.github.io/vega/data/normal-2d.json" ]
                , data "summary" [ daSource "points" ]
                    |> transform
                        [ trAggregate
                            [ agFields [ field "u", field "u" ]
                            , agOps [ Mean, Stdev ]
                            , agAs [ "mean", "stdev" ]
                            ]
                        ]
                , data "density" [ daSource "points" ]
                    |> transform
                        [ trDensity (diKde "points" (field "u") (numSignal "bandWidth"))
                            [ dnExtent (numSignal "domain('xScale')")
                            , dnSteps (numSignal "steps")
                            , dnMethodAsSignal "method"
                            ]
                        ]
                , data "normal" []
                    |> transform
                        [ trDensity (diNormal (numSignal "data('summary')[0].mean") (numSignal "data('summary')[0].stdev"))
                            [ dnExtent (numSignal "domain('xScale')")
                            , dnSteps (numSignal "steps")
                            , dnMethodAsSignal "method"
                            ]
                        ]
                ]

        si =
            signals
                << signal "bandWidth" [ siValue (vNum 0), siBind (iRange [ inMin 0, inMax 0.1, inStep 0.001 ]) ]
                << signal "steps" [ siValue (vNum 100), siBind (iRange [ inMin 10, inMax 500, inStep 1 ]) ]
                << signal "method" [ siValue (vStr "pdf"), siBind (iRadio [ inOptions (vStrs [ "pdf", "cdf" ]) ]) ]

        sc =
            scales
                << scale "xScale"
                    [ scType ScLinear
                    , scRange RaWidth
                    , scDomain (doData [ daDataset "points", daField (field "u") ])
                    , scNice NTrue
                    ]
                << scale "yScale"
                    [ scType ScLinear
                    , scRange RaHeight
                    , scRound true
                    , scDomain
                        (doData
                            [ daReferences
                                [ [ daDataset "density", daField (field "density") ]
                                , [ daDataset "normal", daField (field "density") ]
                                ]
                            ]
                        )
                    ]
                << scale "cScale"
                    [ scType ScOrdinal
                    , scDomain (doStrs (strs [ "Normal Estimate", "Kernel Density Estimate" ]))
                    , scRange (raStrs [ "#444", "steelblue" ])
                    ]

        ax =
            axes << axis "xScale" SBottom [ axZIndex (num 1) ]

        le =
            legends << legend [ leOrient TopLeft, leOffset (vNum 0), leZIndex (num 1), leFill "cScale" ]

        mk =
            marks
                << mark Area
                    [ mFrom [ srData (str "density") ]
                    , mEncode
                        [ enUpdate
                            [ maX [ vScale "xScale", vField (field "value") ]
                            , maY [ vScale "yScale", vField (field "density") ]
                            , maY2 [ vScale "yScale", vNum 0 ]
                            , maFill [ vSignal "scale('cScale', 'Kernel Density Estimate')" ]
                            ]
                        ]
                    ]
                << mark Line
                    [ mFrom [ srData (str "normal") ]
                    , mEncode
                        [ enUpdate
                            [ maX [ vScale "xScale", vField (field "value") ]
                            , maY [ vScale "yScale", vField (field "density") ]
                            , maStroke [ vSignal "scale('cScale', 'Normal Estimate')" ]
                            , maStrokeWidth [ vNum 2 ]
                            ]
                        ]
                    ]
                << mark Rect
                    [ mFrom [ srData (str "points") ]
                    , mEncode
                        [ enEnter
                            [ maX [ vScale "xScale", vField (field "u") ]
                            , maWidth [ vNum 1 ]
                            , maY [ vNum 25, vOffset (vSignal "height") ]
                            , maHeight [ vNum 5 ]
                            , maFill [ vStr "steelblue" ]
                            , maOpacity [ vNum 0.4 ]
                            ]
                        ]
                    ]
    in
    toVega
        [ width 500, height 100, padding 5, ds, si [], sc [], ax [], le [], mk [] ]


boxplot1 : Spec
boxplot1 =
    let
        cf =
            config [ cfAxis AxBand [ axBandPosition (num 1), axTickExtra true, axTickOffset (num 0) ] ]

        ds =
            dataSource
                [ data "iris" [ daUrl "https://vega.github.io/vega/data/iris.json" ]
                    |> transform [ trFoldAs [ fSignal "fields" ] "organ" "value" ]
                ]

        si =
            signals
                << signal "fields" [ siValue (vStrs [ "petalWidth", "petalLength", "sepalWidth", "sepalLength" ]) ]
                << signal "plotWidth" [ siValue (vNum 60) ]
                << signal "height" [ siUpdate "(plotWidth + 10) * length(fields)" ]

        sc =
            scales
                << scale "layout"
                    [ scType ScBand
                    , scRange RaHeight
                    , scDomain (doData [ daDataset "iris", daField (field "organ") ])
                    ]
                << scale "xScale"
                    [ scType ScLinear
                    , scRange RaWidth
                    , scRound true
                    , scDomain (doData [ daDataset "iris", daField (field "value") ])
                    , scZero true
                    , scNice NTrue
                    ]
                << scale "cScale" [ scType ScOrdinal, scRange RaCategory ]

        ax =
            axes
                << axis "xScale" SBottom [ axZIndex (num 1) ]
                << axis "layout" SLeft [ axTickCount (num 5), axZIndex (num 1) ]

        mk =
            marks
                << mark Group
                    [ mFrom [ srFacet "iris" "organs" [ faGroupBy [ "organ" ] ] ]
                    , mEncode
                        [ enEnter
                            [ maYC [ vScale "layout", vField (field "organ"), vBand (num 0.5) ]
                            , maHeight [ vSignal "plotWidth" ]
                            , maWidth [ vSignal "width" ]
                            ]
                        ]
                    , mGroup [ nestedDs, nestedMk [] ]
                    ]

        nestedDs =
            dataSource
                [ data "summary" [ daSource "organs" ]
                    |> transform
                        [ trAggregate
                            [ agFields (List.repeat 5 (field "value"))
                            , agOps [ Min, Q1, Median, Q3, Max ]
                            , agAs [ "min", "q1", "median", "q3", "max" ]
                            ]
                        ]
                ]

        nestedMk =
            marks
                << mark Rect
                    [ mFrom [ srData (str "summary") ]
                    , mEncode
                        [ enEnter
                            [ maFill [ vStr "black" ]
                            , maHeight [ vNum 1 ]
                            ]
                        , enUpdate
                            [ maYC [ vSignal "plotWidth / 2", vOffset (vNum -0.5) ]
                            , maX [ vScale "xScale", vField (field "min") ]
                            , maX2 [ vScale "xScale", vField (field "max") ]
                            ]
                        ]
                    ]
                << mark Rect
                    [ mFrom [ srData (str "summary") ]
                    , mEncode
                        [ enEnter
                            [ maFill [ vStr "steelblue" ]
                            , maCornerRadius [ vNum 4 ]
                            ]
                        , enUpdate
                            [ maYC [ vSignal "plotWidth / 2" ]
                            , maHeight [ vSignal "plotWidth / 2" ]
                            , maX [ vScale "xScale", vField (field "q1") ]
                            , maX2 [ vScale "xScale", vField (field "q3") ]
                            ]
                        ]
                    ]
                << mark Rect
                    [ mFrom [ srData (str "summary") ]
                    , mEncode
                        [ enEnter
                            [ maFill [ vStr "aliceblue" ]
                            , maWidth [ vNum 2 ]
                            ]
                        , enUpdate
                            [ maYC [ vSignal "plotWidth / 2" ]
                            , maHeight [ vSignal "plotWidth / 2" ]
                            , maX [ vScale "xScale", vField (field "median") ]
                            ]
                        ]
                    ]
    in
    toVega
        [ cf, width 500, padding 5, ds, si [], sc [], ax [], mk [] ]


violinplot1 : Spec
violinplot1 =
    let
        cf =
            config [ cfAxis AxBand [ axBandPosition (num 1), axTickExtra true, axTickOffset (num 0) ] ]

        ds =
            dataSource
                [ data "iris" [ daUrl "https://vega.github.io/vega/data/iris.json" ]
                    |> transform [ trFoldAs [ fSignal "fields" ] "organ" "value" ]
                ]

        si =
            signals
                << signal "fields" [ siValue (vStrs [ "petalWidth", "petalLength", "sepalWidth", "sepalLength" ]) ]
                << signal "plotWidth" [ siValue (vNum 60) ]
                << signal "height" [ siUpdate "(plotWidth + 10) * length(fields)" ]
                << signal "bandWidth" [ siValue (vNum 0), siBind (iRange [ inMin 0, inMax 0.5, inStep 0.005 ]) ]
                << signal "steps" [ siValue (vNum 100), siBind (iRange [ inMin 10, inMax 500, inStep 1 ]) ]

        sc =
            scales
                << scale "layout"
                    [ scType ScBand
                    , scRange RaHeight
                    , scDomain (doData [ daDataset "iris", daField (field "organ") ])
                    ]
                << scale "xScale"
                    [ scType ScLinear
                    , scRange RaWidth
                    , scRound true
                    , scDomain (doData [ daDataset "iris", daField (field "value") ])
                    , scZero true
                    , scNice NTrue
                    ]
                << scale "cScale" [ scType ScOrdinal, scRange RaCategory ]

        ax =
            axes
                << axis "xScale" SBottom [ axZIndex (num 1) ]
                << axis "layout" SLeft [ axTickCount (num 5), axZIndex (num 1) ]

        mk =
            marks
                << mark Group
                    [ mFrom [ srFacet "iris" "organs" [ faGroupBy [ "organ" ] ] ]
                    , mEncode
                        [ enEnter
                            [ maYC [ vScale "layout", vField (field "organ"), vBand (num 0.5) ]
                            , maHeight [ vSignal "plotWidth" ]
                            , maWidth [ vSignal "width" ]
                            ]
                        ]
                    , mGroup [ nestedDs, nestedSc [], nestedMk [] ]
                    ]

        nestedDs =
            dataSource
                [ data "density" []
                    |> transform
                        [ trDensity (diKde "organs" (field "value") (numSignal "bandWidth"))
                            [ dnSteps (numSignal "steps") ]
                        , trStack
                            [ stGroupBy [ field "value" ]
                            , stField (field "density")
                            , stOffset OfCenter
                            , stAs "y0" "y1"
                            ]
                        ]
                , data "summary" [ daSource "organs" ]
                    |> transform
                        [ trAggregate
                            [ agFields (List.map field [ "value", "value", "value" ])
                            , agOps [ Q1, Median, Q3 ]
                            , agAs [ "q1", "median", "q3" ]
                            ]
                        ]
                ]

        nestedSc =
            scales
                << scale "yScale"
                    [ scType ScLinear
                    , scRange (raValues [ vNum 0, vSignal "plotWidth" ])
                    , scDomain (doData [ daDataset "density", daField (field "density") ])
                    ]

        nestedMk =
            marks
                << mark Area
                    [ mFrom [ srData (str "density") ]
                    , mEncode
                        [ enEnter [ maFill [ vScale "cScale", vField (fParent (field "organ")) ] ]
                        , enUpdate
                            [ maX [ vScale "xScale", vField (field "value") ]
                            , maY [ vScale "yScale", vField (field "y0") ]
                            , maY2 [ vScale "yScale", vField (field "y1") ]
                            ]
                        ]
                    ]
                << mark Rect
                    [ mFrom [ srData (str "summary") ]
                    , mEncode
                        [ enEnter
                            [ maFill [ vStr "black" ]
                            , maHeight [ vNum 2 ]
                            ]
                        , enUpdate
                            [ maYC [ vSignal "plotWidth / 2" ]
                            , maX [ vScale "xScale", vField (field "q1") ]
                            , maX2 [ vScale "xScale", vField (field "q3") ]
                            ]
                        ]
                    ]
                << mark Rect
                    [ mFrom [ srData (str "summary") ]
                    , mEncode
                        [ enEnter
                            [ maFill [ vStr "black" ]
                            , maWidth [ vNum 2 ]
                            , maHeight [ vNum 8 ]
                            ]
                        , enUpdate
                            [ maYC [ vSignal "plotWidth / 2" ]
                            , maX [ vScale "xScale", vField (field "median") ]
                            ]
                        ]
                    ]
    in
    toVega
        [ cf, width 500, padding 5, ds, si [], sc [], ax [], mk [] ]


window1 : Spec
window1 =
    let
        ds =
            dataSource
                [ data "directors" [ daUrl "https://vega.github.io/vega/data/movies.json" ]
                    |> transform
                        [ trFilter (expr "datum.Director != null && datum.Worldwide_Gross != null")
                        , trAggregate
                            [ agGroupBy [ field "Director" ]
                            , agOps [ opSignal "op" ]
                            , agFields [ field "Worldwide_Gross" ]
                            , agAs [ "Gross" ]
                            ]
                        , trWindow [ wnOperation RowNumber "rank" ]
                            [ wnSort [ ( field "Gross", Descend ) ] ]
                        , trFilter (expr "datum.rank <= k")
                        ]
                ]

        si =
            signals
                << signal "k"
                    [ siValue (vNum 20)
                    , siBind (iRange [ inMin 10, inMax 30, inStep 1 ])
                    ]
                << signal "op"
                    [ siValue (vStr "average")
                    , siBind (iSelect [ inOptions (vStrs [ "average", "median", "sum" ]) ])
                    ]
                << signal "label"
                    [ siValue
                        (vObject
                            [ keyValue "average" (vStr "Average")
                            , keyValue "median" (vStr "Median")
                            , keyValue "sum" (vStr "Total")
                            ]
                        )
                    ]

        ti =
            title (strSignal "'Top Directors by ' + label[op] + ' Worldwide Gross'") [ tiAnchor Start ]

        sc =
            scales
                << scale "xScale"
                    [ scType ScLinear
                    , scRange RaWidth
                    , scDomain (doData [ daDataset "directors", daField (field "Gross") ])
                    , scNice NTrue
                    ]
                << scale "yScale"
                    [ scType ScBand
                    , scRange RaHeight
                    , scDomain
                        (doData
                            [ daDataset "directors"
                            , daField (field "Director")
                            , daSort [ soOp Max, soByField (str "Gross"), Descending ]
                            ]
                        )
                    , scPadding (num 0.1)
                    ]

        ax =
            axes
                << axis "xScale" SBottom [ axFormat "$,d", axTickCount (num 5) ]
                << axis "yScale" SLeft []

        mk =
            marks
                << mark Rect
                    [ mFrom [ srData (str "directors") ]
                    , mEncode
                        [ enUpdate
                            [ maX [ vScale "xScale", vNum 0 ]
                            , maX2 [ vScale "xScale", vField (field "Gross") ]
                            , maY [ vScale "yScale", vField (field "Director") ]
                            , maHeight [ vScale "yScale", vBand (num 1) ]
                            ]
                        ]
                    ]
    in
    toVega
        [ width 500, height 410, padding 5, autosize [ AFit ], ti, ds, si [], sc [], ax [], mk [] ]


window2 : Spec
window2 =
    let
        ds =
            dataSource
                [ data "source" [ daUrl "https://vega.github.io/vega/data/movies.json" ]
                    |> transform [ trFilter (expr "datum.Director != null && datum.Worldwide_Gross != null") ]
                , data "ranks" [ daSource "source" ]
                    |> transform
                        [ trAggregate
                            [ agGroupBy [ field "Director" ]
                            , agOps [ opSignal "op" ]
                            , agFields [ field "Worldwide_Gross" ]
                            , agAs [ "Gross" ]
                            ]
                        , trWindow [ wnOperation RowNumber "rank" ]
                            [ wnSort [ ( field "Gross", Descend ) ] ]
                        ]
                , data "directors" [ daSource "source" ]
                    |> transform
                        [ trLookup "ranks" (field "Director") [ field "Director" ] [ luValues [ field "rank" ] ]
                        , trFormula "datum.rank < k ? datum.Director : 'All Others'" "Category"
                        , trAggregate
                            [ agGroupBy [ field "Category" ]
                            , agOps [ opSignal "op" ]
                            , agFields [ field "Worldwide_Gross" ]
                            , agAs [ "Gross" ]
                            ]
                        ]
                ]

        si =
            signals
                << signal "k"
                    [ siValue (vNum 20)
                    , siBind (iRange [ inMin 10, inMax 30, inStep 1 ])
                    ]
                << signal "op"
                    [ siValue (vStr "average")
                    , siBind (iSelect [ inOptions (vStrs [ "average", "median", "sum" ]) ])
                    ]
                << signal "label"
                    [ siValue
                        (vObject
                            [ keyValue "average" (vStr "Average")
                            , keyValue "median" (vStr "Median")
                            , keyValue "sum" (vStr "Total")
                            ]
                        )
                    ]

        ti =
            title (strSignal "'Top Directors by ' + label[op] + ' Worldwide Gross'") [ tiAnchor Start ]

        sc =
            scales
                << scale "xScale"
                    [ scType ScLinear
                    , scRange RaWidth
                    , scDomain (doData [ daDataset "directors", daField (field "Gross") ])
                    , scNice NTrue
                    ]
                << scale "yScale"
                    [ scType ScBand
                    , scRange RaHeight
                    , scDomain
                        (doData
                            [ daDataset "directors"
                            , daField (field "Category")
                            , daSort [ soOp Max, soByField (str "Gross"), Descending ]
                            ]
                        )
                    , scPadding (num 0.1)
                    ]

        ax =
            axes
                << axis "xScale" SBottom [ axFormat "$,d", axTickCount (num 5) ]
                << axis "yScale" SLeft []

        mk =
            marks
                << mark Rect
                    [ mFrom [ srData (str "directors") ]
                    , mEncode
                        [ enUpdate
                            [ maX [ vScale "xScale", vNum 0 ]
                            , maX2 [ vScale "xScale", vField (field "Gross") ]
                            , maY [ vScale "yScale", vField (field "Category") ]
                            , maHeight [ vScale "yScale", vBand (num 1) ]
                            ]
                        ]
                    ]
    in
    toVega
        [ width 500, height 410, padding 5, autosize [ AFit ], ti, ds, si [], sc [], ax [], mk [] ]


scatter1 : Spec
scatter1 =
    let
        ds =
            dataSource
                [ data "source" [ daUrl "https://vega.github.io/vega/data/cars.json" ]
                    |> transform [ trFilter (expr "datum['Horsepower'] != null && datum['Miles_per_Gallon'] != null") ]
                , data "summary" [ daSource "source" ]
                    |> transform
                        [ trExtentAsSignal (field "Horsepower") "hp_extent"
                        , trBin (field "Horsepower") (numSignal "hp_extent") [ bnMaxBins (num 10), bnAs "hp0" "hp1" ]
                        , trExtentAsSignal (field "Miles_per_Gallon") "mpg_extent"
                        , trBin (field "Miles_per_Gallon") (numSignal "mpg_extent") [ bnMaxBins (num 10), bnAs "mpg0" "mpg1" ]
                        , trAggregate [ agGroupBy (List.map field [ "hp0", "hp1", "mpg0", "mpg1" ]) ]
                        ]
                ]

        sc =
            scales
                << scale "xScale"
                    [ scType ScLinear
                    , scRange RaWidth
                    , scDomain (doData [ daDataset "source", daField (field "Horsepower") ])
                    , scRound true
                    , scNice NTrue
                    , scZero true
                    ]
                << scale "yScale"
                    [ scType ScLinear
                    , scRange RaHeight
                    , scDomain (doData [ daDataset "source", daField (field "Miles_per_Gallon") ])
                    , scRound true
                    , scNice NTrue
                    , scZero true
                    ]
                << scale "sizeScale"
                    [ scType ScLinear
                    , scDomain (doData [ daDataset "summary", daField (field "count") ])
                    , scRange (raNums [ 0, 360 ])
                    , scZero true
                    ]

        ax =
            axes
                << axis "xScale"
                    SBottom
                    [ axGrid true
                    , axDomain false
                    , axTickCount (num 5)
                    , axTitle (str "Horsepower")
                    ]
                << axis "yScale"
                    SLeft
                    [ axGrid true
                    , axDomain false
                    , axTitlePadding (vNum 5)
                    , axTitle (str "Miles per gallon")
                    ]

        le =
            legends
                << legend
                    [ leSize "sizeScale"
                    , leTitle (str "Count")
                    , leEncode
                        [ enSymbols
                            [ enUpdate
                                [ maStrokeWidth [ vNum 2 ]
                                , maStroke [ vStr "#4682b4" ]
                                , maShape [ vStr "circle" ]
                                ]
                            ]
                        ]
                    ]

        mk =
            marks
                << mark Symbol
                    [ mName "marks"
                    , mFrom [ srData (str "summary") ]
                    , mEncode
                        [ enUpdate
                            [ maX [ vScale "xScale", vSignal "(datum.hp0 + datum.hp1) / 2" ]
                            , maY [ vScale "yScale", vSignal "(datum.mpg0 + datum.mpg1) / 2" ]
                            , maSize [ vScale "sizeScale", vField (field "count") ]
                            , maShape [ vStr "circle" ]
                            , maStrokeWidth [ vNum 2 ]
                            , maStroke [ vStr "#4682b4" ]
                            , maFill [ vStr "transparent" ]
                            ]
                        ]
                    ]
    in
    toVega
        [ width 200, height 200, padding 5, autosize [ APad ], ds, sc [], ax [], le [], mk [] ]


contour1 : Spec
contour1 =
    let
        cf =
            config [ cfScaleRange RaHeatmap (raScheme (str "greenblue") []) ]

        ds =
            dataSource
                [ data "source" [ daUrl "https://vega.github.io/vega/data/cars.json" ]
                    |> transform [ trFilter (expr "datum['Horsepower'] != null && datum['Miles_per_Gallon'] != null") ]
                , data "contours" [ daSource "source" ]
                    |> transform
                        [ trContour (numSignal "width")
                            (numSignal "height")
                            [ cnX (fExpr "scale('xScale', datum.Horsepower)")
                            , cnY (fExpr "scale('yScale', datum.Miles_per_Gallon)")
                            , cnCount (numSignal "count")
                            ]
                        ]
                ]

        si =
            signals
                << signal "count" [ siValue (vNum 10), siBind (iSelect [ inOptions (vNums [ 1, 5, 10, 20 ]) ]) ]
                << signal "points" [ siValue (vBoo True), siBind (iCheckbox []) ]

        sc =
            scales
                << scale "xScale"
                    [ scType ScLinear
                    , scRange RaWidth
                    , scDomain (doData [ daDataset "source", daField (field "Horsepower") ])
                    , scRound true
                    , scNice NTrue
                    , scZero false
                    ]
                << scale "yScale"
                    [ scType ScLinear
                    , scRange RaHeight
                    , scDomain (doData [ daDataset "source", daField (field "Miles_per_Gallon") ])
                    , scRound true
                    , scNice NTrue
                    , scZero false
                    ]
                << scale "cScale"
                    [ scType ScSequential
                    , scDomain (doData [ daDataset "contours", daField (field "value") ])
                    , scRange RaHeatmap
                    , scZero true
                    ]

        ax =
            axes
                << axis "xScale"
                    SBottom
                    [ axGrid true
                    , axDomain false
                    , axTitle (str "Horsepower")
                    ]
                << axis "yScale"
                    SLeft
                    [ axGrid true
                    , axDomain false
                    , axTitle (str "Miles per gallon")
                    ]

        le =
            legends << legend [ leFill "cScale", leType LGradient ]

        mk =
            marks
                << mark Path
                    [ mFrom [ srData (str "contours") ]
                    , mEncode
                        [ enEnter
                            [ maStroke [ vStr "#888" ]
                            , maStrokeWidth [ vNum 1 ]
                            , maFill [ vScale "cScale", vField (field "value") ]
                            , maFillOpacity [ vNum 0.35 ]
                            ]
                        ]
                    , mTransform [ trGeoPath "" [ gpField (field "datum") ] ]
                    ]
                << mark Symbol
                    [ mName "marks"
                    , mFrom [ srData (str "source") ]
                    , mEncode
                        [ enUpdate
                            [ maX [ vScale "xScale", vField (field "Horsepower") ]
                            , maY [ vScale "yScale", vField (field "Miles_per_Gallon") ]
                            , maSize [ vNum 4 ]
                            , maFill [ ifElse "points" [ vStr "black" ] [ vStr "transparent" ] ]
                            ]
                        ]
                    ]
    in
    toVega
        [ cf, width 500, height 400, padding 5, autosize [ APad ], ds, si [], sc [], ax [], le [], mk [] ]


wheat1 : Spec
wheat1 =
    let
        ds =
            dataSource
                [ data "points" [ daUrl "https://vega.github.io/vega/data/normal-2d.json" ]
                    |> transform
                        [ trBin (field "u")
                            (nums [ -1, 1 ])
                            [ bnAnchor (numSignal "binOffset")
                            , bnStep (numSignal "binStep")
                            , bnNice false
                            , bnSignal "bins"
                            ]
                        , trStack [ stGroupBy [ field "bin0" ], stSort [ ( field "u", Ascend ) ] ]
                        , trExtentAsSignal (field "y1") "extent"
                        ]
                ]

        si =
            signals
                << signal "symbolDiameter"
                    [ siValue (vNum 4)
                    , siBind (iRange [ inMin 1, inMax 8, inStep 0.25 ])
                    ]
                << signal "binOffset"
                    [ siValue (vNum 0)
                    , siBind (iRange [ inMin -0.1, inMax 0.1 ])
                    ]
                << signal "binStep"
                    [ siValue (vNum 0.075)
                    , siBind (iRange [ inMin -0.001, inMax 0.2, inStep 0.001 ])
                    ]
                << signal "height" [ siUpdate "extent[1] * (1 + symbolDiameter)" ]

        sc =
            scales
                << scale "xScale"
                    [ scType ScLinear
                    , scRange RaWidth
                    , scDomain (doNums (nums [ -1, 1 ]))
                    ]
                << scale "yScale"
                    [ scType ScLinear
                    , scRange RaHeight
                    , scDomain (doNums (numList [ num 0, numSignal "extent[1]" ]))
                    ]

        ax =
            axes
                << axis "xScale"
                    SBottom
                    [ axValues (vSignal "sequence(bins.start, bins.stop + bins.step, bins.step)")
                    , axDomain false
                    , axTicks false
                    , axLabels false
                    , axGrid true
                    , axZIndex (num 0)
                    ]
                << axis "xScale" SBottom [ axZIndex (num 1) ]

        mk =
            marks
                << mark Symbol
                    [ mFrom [ srData (str "points") ]
                    , mEncode
                        [ enEnter
                            [ maFill [ vStr "transparent" ]
                            , maStrokeWidth [ vNum 0.5 ]
                            ]
                        , enUpdate
                            [ maX [ vScale "xScale", vField (field "u") ]
                            , maY [ vScale "yScale", vField (field "y0") ]
                            , maSize [ vSignal "symbolDiameter * symbolDiameter" ]
                            , maStroke [ vStr "steelblue" ]
                            ]
                        , enHover [ maStroke [ vStr "firebrick" ] ]
                        ]
                    ]
    in
    toVega
        [ width 500, padding 5, ds, si [], sc [], ax [], mk [] ]


sourceExample : Spec
sourceExample =
    violinplot1



{- This list comprises the specifications to be provided to the Vega runtime. -}


mySpecs : Spec
mySpecs =
    combineSpecs
        [ ( "histo1", histo1 )
        , ( "histo2", histo2 )
        , ( "density1", density1 )
        , ( "boxplot1", boxplot1 )
        , ( "violinplot1", violinplot1 )
        , ( "window1", window1 )
        , ( "window2", window2 )
        , ( "scatter1", scatter1 )
        , ( "contour1", contour1 )
        , ( "wheat1", wheat1 )
        ]



{- ---------------------------------------------------------------------------
   The code below creates an Elm module that opens an outgoing port to Javascript
   and sends both the specs and DOM node to it.
   This is used to display the generated Vega specs for testing purposes.
-}


main : Program Never Spec msg
main =
    Html.program
        { init = ( mySpecs, elmToJS mySpecs )
        , view = view
        , update = \_ model -> ( model, Cmd.none )
        , subscriptions = always Sub.none
        }



-- View


view : Spec -> Html msg
view spec =
    div []
        [ div [ id "specSource" ] []
        , pre []
            [ Html.text (Json.Encode.encode 2 sourceExample) ]
        ]


port elmToJS : Spec -> Cmd msg
