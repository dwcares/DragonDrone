package com.bsherwin.MavicDragon;

public interface OnCSTaskCompleted{
    void onDetectCompleted(String result);
    void onIndentifyCompleted(String personId);
    void onGetPersonCompleted(String personName);
}
