#!/bin/bash
# 勤怠記録ファイルのパス
ATTENDANCE_CSV_FILE="$HOME/Desktop/attendance_record.csv"
ATTENDANCE_TXT_FILE="$HOME/Desktop/attendance_record.txt"

# CSVヘッダーの初期化
if [ ! -f "$ATTENDANCE_CSV_FILE" ]; then
    echo "日付,出勤時刻,退勤時刻,稼働時間,記録タイプ" >$ATTENDANCE_CSV_FILE
fi

# 現在の日付を取得
current_date=$(date "+%Y-%m-%d")

# 勤務開始
start_work() {

    # 最新の記録をチェック
    last_record=$(tail -1 $ATTENDANCE_TXT_FILE)
    # 最新の記録が手動記録の場合
    if [[ "$last_record" == *"勤務開始"* ]] && [[ "$last_record" != *"勤務終了"* ]] && [[ "$last_record" != *"手動記録"* ]]; then
        echo "出勤時刻がすでに打刻されています"
        return
    fi

    echo -n "任意の出勤時刻を入力しますか？（y/n）: "
    read answer
    if [[ "$answer" == "y" ]]; then
        echo -n "開始時刻を入力してください（例: 21:30、または 2024/01/28 21:30）: "
        read input_start_time

        # 秒数が省略された場合、秒数を追加
        if [[ ! $input_start_time == *:*:* ]]; then
            input_start_time="${input_start_time}:00"
        fi

        # 年月日が省略された場合、現在の日付を追加
        if [[ ! $input_start_time == */*/* ]]; then
            today=$(date "+%Y/%m/%d")
            input_start_time="$today $input_start_time"
        fi

        # 入力された日付と時刻をフォーマット変換
        start_time=$(date -j -f "%Y/%m/%d %H:%M:%S" "$input_start_time" "+%Y-%m-%d %H:%M:%S" 2>/dev/null)

        # date コマンドのエラーチェック
        if [ $? -ne 0 ]; then
            echo "入力された日付のフォーマットが正しくありません。"
            return
        fi
    else
        start_time=$(date "+%Y-%m-%d %H:%M:%S")
    fi

    echo -n "自動記録: 勤務開始 $start_time," >>$ATTENDANCE_TXT_FILE
    echo "出勤時刻を記録しました: $start_time"
}

# 勤務終了
end_work() {
    # 最新の記録をチェック
    last_record=$(tail -1 $ATTENDANCE_TXT_FILE)

    # 最新の記録が手動記録の場合
    if [[ "$last_record" == *"勤務開始"* ]] && [[ "$last_record" == *"勤務終了"* ]]; then
        echo "出勤時刻が打刻されていません。"
        return
    fi

    # 最新の記録が勤務終了である場合
    if [[ "$last_record" == *"勤務終了"* ]]; then
        echo "既に退勤時刻は打刻されています。"
        return
    fi

    # 最新の記録から勤務出勤時刻を抽出
    start_time=$(echo "$last_record" | awk '{match($0, /[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}/); print substr($0, RSTART, RLENGTH)}')

    if [ -z "$start_time" ]; then
        echo "出勤時刻が打刻されていません。"
        return
    fi

    echo -n "任意の退勤時刻を入力しますか？（y/n）: "
    read answer
    if [[ "$answer" == "y" ]]; then
        echo -n "退勤時刻を入力してください（例: 21:30、または 2024/01/28 21:30）: "
        read input_end_time

        # 秒数が省略された場合、秒数を追加
        if [[ ! $input_end_time == *:*:* ]]; then
            input_end_time="${input_end_time}:00"
        fi

        # 年月日が省略された場合、現在の日付を追加
        if [[ ! $input_end_time == */*/* ]]; then
            today=$(date "+%Y/%m/%d")
            input_end_time="$today $input_end_time"
        fi

        # 入力された日付と時刻をフォーマット変換
        end_time=$(date -j -f "%Y/%m/%d %H:%M:%S" "$input_end_time" "+%Y-%m-%d %H:%M:%S" 2>/dev/null)

        # date コマンドのエラーチェック
        if [ $? -ne 0 ]; then
            echo "入力された日付のフォーマットが正しくありません。"
            return
        fi

        # start_time と end_time を秒単位で比較
        start_sec=$(date -j -f "%Y-%m-%d %H:%M:%S" "$start_time" "+%s")
        end_sec=$(date -j -f "%Y-%m-%d %H:%M:%S" "$end_time" "+%s")

        if [ $end_sec -lt $start_sec ]; then
            echo "過去の日付は設定できません。"
            return
        fi

    else
        end_time=$(date "+%Y-%m-%d %H:%M:%S")
    fi

    work_duration=$(calculate_duration "$start_time" "$end_time")
    if [ -z "$work_duration" ]; then
        echo "稼働時間の計算に失敗しました。"
        return
    fi
    echo -n " 勤務終了 $end_time, 稼働時間: $work_duration" >>$ATTENDANCE_TXT_FILE
    echo "" >>$ATTENDANCE_TXT_FILE
    echo "$current_date,$start_time,$end_time,$work_duration,自動" >>$ATTENDANCE_CSV_FILE
    echo "退勤時刻を記録しました: $end_time"
    echo "稼働時間: $work_duration"
}

calculate_duration() {
    start_time="$1"
    end_time="$2"

    # macOSのdateコマンドで日付を解析
    start_sec=$(date -j -f "%Y-%m-%d %H:%M:%S" "$start_time" "+%s")
    end_sec=$(date -j -f "%Y-%m-%d %H:%M:%S" "$end_time" "+%s")

    # date コマンドのエラーチェック
    if [ $? -ne 0 ]; then
        echo "日付の解析エラーが発生しました。"
        return
    fi

    duration_sec=$((end_sec - start_sec))
    if [ $duration_sec -lt 0 ]; then
        echo "終了時刻が出勤時刻より前です。"
        return
    fi

    hours=$((duration_sec / 3600))
    minutes=$(((duration_sec % 3600) / 60))
    seconds=$((duration_sec % 60))
    echo "${hours}h${minutes}min${seconds}s"
}

# 手動で稼働時間を記録
record_manual_hours() {
    echo -n "稼働時間を入力してください（例: 8h30min30s）: "
    read manual_hours

    # 時間、分、秒を抽出
    hour=$(echo $manual_hours | grep -oE '[0-9]+h' | grep -oE '[0-9]+')
    minute=$(echo $manual_hours | grep -oE '[0-9]+min' | grep -oE '[0-9]+')
    second=$(echo $manual_hours | grep -oE '[0-9]+s' | grep -oE '[0-9]+')

    # 未入力の場合は0とする
    hour=${hour:-0}
    minute=${minute:-0}
    second=${second:-0}

    # 入力された時間、分、秒を秒単位で計算
    total_sec=$((hour * 3600 + minute * 60 + second))

    # 現在の日付と時刻を取得
    end_time=$(date "+%Y-%m-%d %H:%M:%S")
    # 現在の秒数を取得
    end_sec=$(date -j -f "%Y-%m-%d %H:%M:%S" "$end_time" "+%s")
    # 出勤時刻の秒数を計算
    start_sec=$((end_sec - total_sec))
    # 出勤時刻をフォーマットに合わせて変換
    start_time=$(date -j -f "%s" "$start_sec" "+%Y-%m-%d %H:%M:%S")

    echo "$current_date,$start_time,$end_time,$manual_hours,手動" >>$ATTENDANCE_CSV_FILE
    echo "手動記録: 勤務開始 $start_time, 勤務終了 $end_time, 稼働時間: $manual_hours" >>$ATTENDANCE_TXT_FILE
    echo "手動記録が追加されました: 勤務開始 $start_time, 勤務終了 $end_time, 稼働時間: $manual_hours"
}

# 記録のエクスポート
export_records() {
    echo -n "エクスポートするファイル名を入力してください（例: export.csv）: "
    read export_file_name
    cp $ATTENDANCE_CSV_FILE "$HOME/Desktop/$export_file_name"
    echo "記録がエクスポートされました: $HOME/Desktop/$export_file_name"
}

# 直前の記録を削除
delete_last_record() {
    sed -i '' '$ d' $ATTENDANCE_CSV_FILE
    sed -i '' '$ d' $ATTENDANCE_TXT_FILE
    echo "直前の記録が削除されました"
}

# メインメニュー
echo "1. 勤務開始"
echo "2. 勤務終了"
echo "3. 手動で稼働時間を記録"
echo "4. 記録をエクスポート"
echo "5. 直前の記録を削除"
echo -n "オプションを選択してください: "
read option

case $option in
1) start_work ;;
2) end_work ;;
3) record_manual_hours ;;
4) export_records ;;
5) delete_last_record ;;
*)
    echo "無効なオプションです"
    exit 1
    ;;
esac
